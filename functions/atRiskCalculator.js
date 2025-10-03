const {onRequest} = require("firebase-functions/v2/https");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

// At-Risk Calculation Functions
async function calculateAndUpdateAtRiskStatus(studentId) {
  try {
    console.log(`Calculating at-risk status for student: ${studentId}`);
    
    const now = new Date();
    
    // Get user creation date to only count attendance from enrollment
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(studentId)
      .get();
      
    if (!userDoc.exists) {
      console.log(`User ${studentId} not found`);
      return null;
    }
    
    const userData = userDoc.data();
    const userCreationDate = userData.createdAt ? userData.createdAt.toDate() : new Date(userData.metadata?.creationTime || now);
    
    console.log(`User ${studentId} created on: ${userCreationDate.toDateString()}`);
    
    // Calculate weekly period (Monday of current week to today, but not before user creation)
    const weekStart = getWeekStartDate(now);
    const effectiveWeekStart = weekStart > userCreationDate ? weekStart : userCreationDate;
    const weeklyAbsences = await getStudentAbsencesForPeriod(studentId, effectiveWeekStart, now);
    const weeklyWeekdays = countWeekdays(effectiveWeekStart, now);
    
    // Calculate monthly period (30 days ago to today, but not before user creation)
    const monthStart = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));
    const effectiveMonthStart = monthStart > userCreationDate ? monthStart : userCreationDate;
    const monthlyAbsences = await getStudentAbsencesForPeriod(studentId, effectiveMonthStart, now);
    const monthlyWeekdays = countWeekdays(effectiveMonthStart, now);
    
    // Apply thresholds: 2+ weekly OR 8+ monthly = At Risk
    const weeklyRisk = weeklyAbsences >= 2;
    const monthlyRisk = monthlyAbsences >= 8;
    const isAtRisk = weeklyRisk || monthlyRisk;
    
    // Prepare the data to store
    const atRiskData = {
      isAtRisk: isAtRisk,
      weeklyAbsences: weeklyAbsences,
      monthlyAbsences: monthlyAbsences,
      weeklyWeekdays: weeklyWeekdays,
      monthlyWeekdays: monthlyWeekdays,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      
      riskFactors: {
        weeklyRisk: weeklyRisk,
        monthlyRisk: monthlyRisk
      },
      
      thresholds: {
        weekly: 2,
        monthly: 8
      },
      
      periods: {
        weekStart: admin.firestore.Timestamp.fromDate(effectiveWeekStart),
        monthStart: admin.firestore.Timestamp.fromDate(effectiveMonthStart),
        userCreationDate: admin.firestore.Timestamp.fromDate(userCreationDate),
        calculatedAt: admin.firestore.FieldValue.serverTimestamp()
      }
    };
    
    // Store in Firestore at users/{studentId}/at-risk/current_status
    await admin.firestore()
      .collection('users')
      .doc(studentId)
      .collection('at-risk')
      .doc('current_status')
      .set(atRiskData);
      
    console.log(`At-risk status updated for ${studentId}: ${isAtRisk ? 'AT RISK' : 'NOT AT RISK'} (Weekly: ${weeklyAbsences}/${weeklyWeekdays} from ${effectiveWeekStart.toDateString()}, Monthly: ${monthlyAbsences}/${monthlyWeekdays} from ${effectiveMonthStart.toDateString()})`);
    
    return atRiskData;
    
  } catch (error) {
    console.error(`Error calculating at-risk status for ${studentId}:`, error);
    throw error;
  }
}

// Helper function: Get Monday of current week
function getWeekStartDate(currentDate) {
  const date = new Date(currentDate);
  const day = date.getDay(); // 0 = Sunday, 1 = Monday, etc.
  const diff = day === 0 ? -6 : 1 - day; // Adjust for Monday start
  date.setDate(date.getDate() + diff);
  date.setHours(0, 0, 0, 0); // Start of day
  return date;
}

// Helper function: Count weekdays (Monday-Friday) in date range
function countWeekdays(startDate, endDate) {
  const start = new Date(startDate);
  const end = new Date(endDate);
  let count = 0;
  
  while (start <= end) {
    const dayOfWeek = start.getDay();
    // Count Monday(1) through Friday(5) only - school operates weekdays only
    if (dayOfWeek >= 1 && dayOfWeek <= 5) {
      count++;
    }
    start.setDate(start.getDate() + 1);
  }
  
  return count;
}

// Helper function: Get next weekday (Monday-Friday) from given date
function getNextWeekday(date) {
  const nextDay = new Date(date);
  while (nextDay.getDay() < 1 || nextDay.getDay() > 5) {
    nextDay.setDate(nextDay.getDate() + 1);
  }
  return nextDay;
}

// Helper function: Get previous weekday (Monday-Friday) from given date  
function getPreviousWeekday(date) {
  const prevDay = new Date(date);
  while (prevDay.getDay() < 1 || prevDay.getDay() > 5) {
    prevDay.setDate(prevDay.getDate() - 1);
  }
  return prevDay;
}

// Helper function: Check if date is a weekday (Monday-Friday)
function isWeekday(date) {
  const day = date.getDay();
  return day >= 1 && day <= 5;
}

// Helper function: Get student absences for a specific period (weekdays only, from user creation date)
async function getStudentAbsencesForPeriod(studentId, startDate, endDate) {
  try {
    // Ensure we're only looking at weekdays (Monday-Friday)
    const adjustedStartDate = getNextWeekday(startDate);
    const adjustedEndDate = getPreviousWeekday(endDate);
    
    // If no weekdays in range, return 0
    if (adjustedStartDate > adjustedEndDate) {
      console.log(`No weekdays in range for ${studentId} from ${startDate.toDateString()} to ${endDate.toDateString()}`);
      return 0;
    }
    
    // Query attendance records for the period (only weekdays)
    const attendanceQuery = await admin.firestore()
      .collection('attendance')
      .doc(studentId)
      .collection('days')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(adjustedStartDate))
      .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(adjustedEndDate))
      .get();
    
    let recordedAbsences = 0;
    const recordedWeekdays = new Set();
    
    // Count recorded absences and track which weekdays have records
    attendanceQuery.forEach(doc => {
      const data = doc.data();
      const recordDate = data.createdAt.toDate();
      
      // Double-check it's a weekday (Monday-Friday only)
      const dayOfWeek = recordDate.getDay();
      if (dayOfWeek >= 1 && dayOfWeek <= 5) {
        const dayKey = recordDate.toDateString();
        recordedWeekdays.add(dayKey);
        
        if (data.status === 'absent') {
          recordedAbsences++;
        }
      }
    });
    
    // Count total weekdays in the period
    const totalWeekdaysInPeriod = countWeekdays(adjustedStartDate, adjustedEndDate);
    
    // Count unrecorded weekdays as absences (no record = absent)
    // This is conservative: assumes missing attendance record means absent
    const unrecordedAbsences = Math.max(0, totalWeekdaysInPeriod - recordedWeekdays.size);
    
    const totalAbsences = recordedAbsences + unrecordedAbsences;
    
    console.log(`Weekday absences for ${studentId} from ${adjustedStartDate.toDateString()} to ${adjustedEndDate.toDateString()}: Total weekdays: ${totalWeekdaysInPeriod}, Recorded weekdays: ${recordedWeekdays.size}, Recorded absences: ${recordedAbsences}, Unrecorded absences: ${unrecordedAbsences}, Total absences: ${totalAbsences}`);
    
    return totalAbsences;
    
  } catch (error) {
    console.error(`Error getting absences for student ${studentId}:`, error);
    return 0;
  }
}

// TRIGGER: When attendance is added/updated/deleted, recalculate at-risk status
exports.onAttendanceUpdate = onDocumentWritten("attendance/{studentId}/days/{dayId}", async (event) => {
  try {
    const studentId = event.params.studentId;
    console.log(`Attendance changed for student ${studentId}, recalculating at-risk status...`);
    
    await calculateAndUpdateAtRiskStatus(studentId);
    console.log(`At-risk status updated for student ${studentId} due to attendance change`);
    
  } catch (error) {
    console.error('Error updating at-risk status on attendance change:', error);
  }
});

// SCHEDULED: Daily batch update for all students at 2:00 AM
exports.dailyAtRiskUpdate = onSchedule("0 2 * * *", async (context) => {
  console.log("Starting daily at-risk batch update for all students...");
  
  try {
    // Get all students
    const studentsQuery = await admin.firestore()
      .collection('users')
      .where('role', '==', 'student')
      .get();
    
    const updatePromises = [];
    
    studentsQuery.forEach(doc => {
      const studentId = doc.id;
      updatePromises.push(calculateAndUpdateAtRiskStatus(studentId));
    });
    
    const results = await Promise.allSettled(updatePromises);
    
    let successCount = 0;
    let errorCount = 0;
    
    results.forEach((result, index) => {
      if (result.status === 'fulfilled') {
        successCount++;
      } else {
        errorCount++;
        console.error(`Failed to update student ${studentsQuery.docs[index].id}:`, result.reason);
      }
    });
    
    console.log(`Daily at-risk update completed: ${successCount} successful, ${errorCount} errors`);
    
  } catch (error) {
    console.error("Error during daily at-risk update:", error);
  }
});

// MANUAL: Calculate at-risk status for all students (for initial setup or manual trigger)
exports.calculateAllStudentsAtRisk = onRequest(async (req, res) => {
  try {
    console.log("Manual calculation of at-risk status for all students started...");
    
    // Get all students
    const studentsQuery = await admin.firestore()
      .collection('users')
      .where('role', '==', 'student')
      .get();
    
    const results = [];
    
    // Process each student
    for (const doc of studentsQuery.docs) {
      const studentId = doc.id;
      const studentData = doc.data();
      const studentName = studentData.name || 'Unknown';
      
      try {
        const atRiskData = await calculateAndUpdateAtRiskStatus(studentId);
        results.push({
          studentId,
          studentName,
          success: true,
          isAtRisk: atRiskData.isAtRisk,
          weeklyAbsences: atRiskData.weeklyAbsences,
          monthlyAbsences: atRiskData.monthlyAbsences,
          weeklyRisk: atRiskData.riskFactors.weeklyRisk,
          monthlyRisk: atRiskData.riskFactors.monthlyRisk
        });
      } catch (error) {
        console.error(`Failed to calculate at-risk status for student ${studentId}:`, error);
        results.push({
          studentId,
          studentName,
          success: false,
          error: error.message
        });
      }
    }
    
    const successCount = results.filter(r => r.success).length;
    const errorCount = results.filter(r => !r.success).length;
    const atRiskCount = results.filter(r => r.success && r.isAtRisk).length;
    
    console.log(`Manual at-risk calculation completed: ${successCount} successful, ${errorCount} errors, ${atRiskCount} students at risk`);
    
    res.status(200).json({
      success: true,
      message: `At-risk calculation completed for ${results.length} students`,
      summary: {
        total: results.length,
        successful: successCount,
        errors: errorCount,
        atRisk: atRiskCount
      },
      results: results
    });
    
  } catch (error) {
    console.error("Error in manual at-risk calculation:", error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// UTILITY: Get at-risk status for a specific student (for testing)
exports.getStudentAtRiskStatus = onRequest(async (req, res) => {
  try {
    const studentId = req.query.studentId;
    
    if (!studentId) {
      return res.status(400).json({
        success: false,
        error: "studentId parameter is required"
      });
    }
    
    // Get current at-risk status from Firestore
    const atRiskDoc = await admin.firestore()
      .collection('users')
      .doc(studentId)
      .collection('at-risk')
      .doc('current_status')
      .get();
    
    if (!atRiskDoc.exists) {
      return res.status(404).json({
        success: false,
        error: "No at-risk data found for this student"
      });
    }
    
    const atRiskData = atRiskDoc.data();
    
    res.status(200).json({
      success: true,
      studentId: studentId,
      atRiskData: atRiskData
    });
    
  } catch (error) {
    console.error("Error getting student at-risk status:", error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});