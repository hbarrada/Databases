-- This file will contain all your views
-- Helper view
DROP VIEW IF EXISTS PassedCourses CASCADE;
CREATE OR REPLACE VIEW PassedCourses AS (
    SELECT t.student, t.course, c.credits
    FROM Taken t JOIN Courses c ON t.course = c.code
    WHERE (t.grade != 'U')
);
--**********************************************************************************************************************
-- Helper view
DROP VIEW IF EXISTS UnreadMandatory CASCADE;
CREATE OR REPLACE VIEW UnreadMandatory AS (
WITH ProgramMandatory AS (
    SELECT s.idnr AS student, mp.course
    FROM Students s JOIN MandatoryProgram mp ON s.program = mp.program
),
BranchMandatory AS (
    SELECT sb.student, mb.course
    FROM StudentBranches sb JOIN MandatoryBranch mb ON sb.branch = mb.branch AND sb.program = mb.program
),
AllMandatory AS (
    SELECT * FROM ProgramMandatory 
    UNION 
    SELECT * FROM BranchMandatory
)
SELECT DISTINCT am.student, am.course
FROM AllMandatory am LEFT JOIN PassedCourses pc ON am.student = pc.student AND am.course = pc.course
WHERE pc.course IS NULL
ORDER BY am.student, am.course
);
--**********************************************************************************************************************
-- Helper view
DROP VIEW IF EXISTS RecommendedCourses CASCADE;
CREATE OR REPLACE VIEW RecommendedCourses AS
SELECT DISTINCT pc.student, pc.course, pc.credits
FROM PassedCourses pc
JOIN RecommendedBranch rb ON pc.course = rb.course
JOIN StudentBranches sb ON sb.student = pc.student 
    AND sb.branch = rb.branch 
    AND sb.program = rb.program;
--**********************************************************************************************************************
DROP VIEW IF EXISTS BasicInformation CASCADE;
CREATE OR REPLACE VIEW BasicInformation AS (
    SELECT st.idnr, st.name, st.login, st.program, stb.branch
    FROM Students st LEFT JOIN StudentBranches stb ON (st.idnr = stb.student)
    ORDER BY st.idnr
); 
--**********************************************************************************************************************
DROP VIEW IF EXISTS FinishedCourses CASCADE;
CREATE OR REPLACE VIEW FinishedCourses AS (
    SELECT t.student, t.course, t.grade,
           c.name AS coursename, 
           c.credits
    FROM Taken t JOIN Courses c ON (t.course = c.code)
    ORDER BY t.student, t.course
);
--**********************************************************************************************************************
DROP VIEW IF EXISTS Registrations CASCADE;
CREATE OR REPLACE VIEW Registrations AS
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
--**********************************************************************************************************************
DROP VIEW IF EXISTS PathToGraduation CASCADE;
CREATE OR REPLACE VIEW PathToGraduation AS
WITH 
MandatoryLeft AS (
    SELECT student, COUNT(course) AS mandatoryLeft
    FROM UnreadMandatory
    GROUP BY student
),
MathCredits AS (
    SELECT pc.student, COALESCE(SUM(pc.credits), 0) AS mathCredits
    FROM PassedCourses pc
    JOIN Classified cl ON pc.course = cl.course
    WHERE cl.classification = 'math'
    GROUP BY pc.student
),
SeminarCourses AS (
    SELECT pc.student, COUNT(*) AS seminarCourses
    FROM PassedCourses pc
    JOIN Classified cl ON pc.course = cl.course
    WHERE cl.classification = 'seminar'
    GROUP BY pc.student
),
RecommendedCredits AS (
 SELECT student, COALESCE(SUM(credits), 0) as recommendedCredits
    FROM RecommendedCourses
    GROUP BY student
)
SELECT 
    s.idnr AS student,
    COALESCE(SUM(pc.credits), 0) AS totalcredits,
    COALESCE(ml.mandatoryLeft, 0) AS mandatoryleft,
    COALESCE(mc.mathCredits, 0) AS mathcredits,
    COALESCE(sc.seminarCourses, 0) AS seminarcourses,
    (COALESCE(ml.mandatoryLeft, 0) = 0 AND
     COALESCE(mc.mathCredits, 0) >= 20 AND
     COALESCE(sc.seminarCourses, 0) >= 1 AND
     COALESCE(rc.recommendedCredits, 0) >= 10) AS qualified
FROM Students s
LEFT JOIN PassedCourses pc ON s.idnr = pc.student
LEFT JOIN MandatoryLeft ml ON s.idnr = ml.student
LEFT JOIN MathCredits mc ON s.idnr = mc.student
LEFT JOIN SeminarCourses sc ON s.idnr = sc.student
LEFT JOIN RecommendedCredits rc ON s.idnr = rc.student
GROUP BY s.idnr, ml.mandatoryLeft, mc.mathCredits, sc.seminarCourses, rc.recommendedCredits
ORDER BY s.idnr;
