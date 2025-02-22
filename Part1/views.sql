-- Helper view: PassedCourses
CREATE VIEW PassedCourses AS
SELECT student, course, credits
FROM Taken
JOIN Courses ON Taken.course = Courses.code
WHERE grade != 'U';

-- Helper view: UnreadMandatory
CREATE VIEW UnreadMandatory AS
SELECT Students.idnr AS student, MandatoryProgram.course
FROM Students
JOIN MandatoryProgram ON Students.program = MandatoryProgram.program
WHERE (Students.idnr, MandatoryProgram.course) NOT IN (
    SELECT student, course FROM PassedCourses
)
UNION
SELECT StudentBranches.student, MandatoryBranch.course
FROM StudentBranches
JOIN MandatoryBranch ON StudentBranches.branch = MandatoryBranch.branch 
    AND StudentBranches.program = MandatoryBranch.program
WHERE (StudentBranches.student, MandatoryBranch.course) NOT IN (
    SELECT student, course FROM PassedCourses
);

-- Helper view: RecommendedCourses
CREATE VIEW RecommendedCourses AS
SELECT DISTINCT pc.student, pc.course, pc.credits
FROM PassedCourses pc
JOIN RecommendedBranch rb ON pc.course = rb.course
JOIN StudentBranches sb ON sb.student = pc.student 
    AND sb.branch = rb.branch 
    AND sb.program = rb.program;

-- Main views as per requirements
CREATE VIEW BasicInformation AS
SELECT 
    Students.idnr,
    Students.name,
    Students.login,
    Students.program,
    StudentBranches.branch
FROM Students
LEFT JOIN StudentBranches ON Students.idnr = StudentBranches.student;

CREATE VIEW FinishedCourses AS
SELECT 
    Taken.student,
    Taken.course,
    Courses.name AS courseName,
    Taken.grade,
    Courses.credits
FROM Taken
JOIN Courses ON Taken.course = Courses.code;

CREATE VIEW Registrations AS
SELECT 
    student,
    course,
    'registered' AS status
FROM Registered
UNION
SELECT 
    student,
    course,
    'waiting' AS status
FROM WaitingList;

CREATE VIEW PathToGraduation AS
WITH 
TotalCredits AS (
    SELECT student, COALESCE(SUM(credits), 0) as totalCredits
    FROM PassedCourses
    GROUP BY student
),
MandatoryLeft AS (
    SELECT student, COUNT(course) as mandatoryLeft
    FROM UnreadMandatory
    GROUP BY student
),
MathCredits AS (
    SELECT pc.student, COALESCE(SUM(pc.credits), 0) as mathCredits
    FROM PassedCourses pc
    JOIN Classified c ON pc.course = c.course
    WHERE c.classification = 'math'
    GROUP BY pc.student
),
SeminarCourses AS (
    SELECT pc.student, COUNT(DISTINCT pc.course) as seminarCourses
    FROM PassedCourses pc
    JOIN Classified c ON pc.course = c.course
    WHERE c.classification = 'seminar'
    GROUP BY pc.student
),
RecommendedCredits AS (
    SELECT student, COALESCE(SUM(credits), 0) as recommendedCredits
    FROM RecommendedCourses
    GROUP BY student
)
SELECT 
    s.idnr AS student,
    COALESCE(tc.totalCredits, 0) AS totalCredits,
    COALESCE(ml.mandatoryLeft, 0) AS mandatoryLeft,
    COALESCE(mc.mathCredits, 0) AS mathCredits,
    COALESCE(sc.seminarCourses, 0) AS seminarCourses,
    (COALESCE(mc.mathCredits, 0) >= 20 AND
     COALESCE(sc.seminarCourses, 0) >= 1 AND
     COALESCE(ml.mandatoryLeft, 0) = 0 AND
     COALESCE(rc.recommendedCredits, 0) >= 10) AS qualified
FROM Students s
LEFT JOIN TotalCredits tc ON s.idnr = tc.student
LEFT JOIN MandatoryLeft ml ON s.idnr = ml.student
LEFT JOIN MathCredits mc ON s.idnr = mc.student
LEFT JOIN SeminarCourses sc ON s.idnr = sc.student
LEFT JOIN RecommendedCredits rc ON s.idnr = rc.student;
