-- This is a file for running offline tests on your triggers. 
-- It does a number of modifications and queries, and also contains
-- the correct output you shuld get.
-- Take the runsetup.sql file from part 1 and modify it to run tables, views,
-- inserts, triggers, tests in that order. 
-- NOTE: Make sure to check that the deletes report the correct
-- number of affected rows!


\echo Testing initial setup
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- course       student  status      position
-----------  ----------  ----------  ----------
-- CCC333    1111111111  registered
-- CCC333    2222222222  registered
-- CCC333    3333333333  registered


\echo test1
INSERT INTO Registrations VALUES ('1111111111', 'CCC111');
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- course       student  status      position
-----------  ----------  ----------  ----------
-- CCC111    1111111111  registered
-- CCC333    1111111111  registered
-- CCC333    2222222222  registered
-- CCC333    3333333333  registered


\echo test2
INSERT INTO Registrations VALUES ('5555555555', 'CCC333');
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- course       student  status        position
-----------  ----------  ----------  ----------
-- CCC111    1111111111  registered
-- CCC333    1111111111  registered
-- CCC333    2222222222  registered
-- CCC333    3333333333  registered
-- CCC333    5555555555  waiting              1


\echo test3
INSERT INTO Registrations VALUES ('6666666666', 'CCC333');
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- course       student  status        position
-----------  ----------  ----------  ----------
-- CCC111    1111111111  registered
-- CCC333    1111111111  registered
-- CCC333    2222222222  registered
-- CCC333    3333333333  registered
-- CCC333    5555555555  waiting              1
-- CCC333    6666666666  waiting              2


\echo test4
INSERT INTO Registrations VALUES ('6666666666', 'CCC222');
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- course       student  status        position
-----------  ----------  ----------  ----------
-- CCC111    1111111111  registered
-- CCC222    6666666666  registered
-- CCC333    1111111111  registered
-- CCC333    2222222222  registered
-- CCC333    3333333333  registered
-- CCC333    5555555555  waiting              1
-- CCC333    6666666666  waiting              2


\echo test5
INSERT INTO Registrations VALUES ('2222222222', 'CCC222');
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- course       student  status        position
-----------  ----------  ----------  ----------
-- CCC111    1111111111  registered
-- CCC222    2222222222  waiting              1
-- CCC222    6666666666  registered
-- CCC333    1111111111  registered
-- CCC333    2222222222  registered
-- CCC333    3333333333  registered
-- CCC333    5555555555  waiting              1
-- CCC333    6666666666  waiting              2


\echo test6
INSERT INTO Registrations VALUES ('5555555555', 'CCC444');
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- course       student  status        position
-----------  ----------  ----------  ----------
-- CCC111    1111111111  registered
-- CCC222    2222222222  waiting              1
-- CCC222    6666666666  registered
-- CCC333    1111111111  registered
-- CCC333    2222222222  registered
-- CCC333    3333333333  registered
-- CCC333    5555555555  waiting              1
-- CCC333    6666666666  waiting              2
-- CCC444    5555555555  registered


\echo test7
\set ON_ERROR_STOP OFF
INSERT INTO Registrations VALUES ('4444444444', 'CCC111');
-- Failure: Student has passed course


\echo test8
INSERT INTO Registrations VALUES ('1111111111', 'CCC111');
-- Failure: Already registered or in waiting list


\echo test9
INSERT INTO Registrations VALUES ('5555555555', 'CCC333');
-- Failure: Already registered or in waiting list


\echo test10
INSERT INTO Registrations VALUES ('6666666666', 'CCC444');
-- Failure: Student has not passed all the prerequisite courses.


\echo test11
INSERT INTO Registrations VALUES ('2222222222', 'CCC444');
-- Failure: Student has not passed all the prerequisite courses.
\set ON_ERROR_STOP ON


\echo test12
-- Make sure psql reports DELETE 2 here!
-- Note that the course is overfull, so nobody is moved from the waiting list
DELETE FROM Registrations WHERE student='1111111111'; 
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- DELETE 2
-- course       student  status        position
-----------  ----------  ----------  ----------
-- CCC222    2222222222  waiting              1
-- CCC222    6666666666  registered
-- CCC333    2222222222  registered
-- CCC333    3333333333  registered
-- CCC333    5555555555  waiting              1
-- CCC333    6666666666  waiting              2
-- CCC444    5555555555  registered


\echo test13
INSERT INTO Registrations VALUES ('1111111111', 'CCC333');
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- course       student  status        position
-----------  ----------  ----------  ----------
-- CCC222    2222222222  waiting              1
-- CCC222    6666666666  registered
-- CCC333    1111111111  waiting              3
-- CCC333    2222222222  registered
-- CCC333    3333333333  registered
-- CCC333    5555555555  waiting              1
-- CCC333    6666666666  waiting              2
-- CCC444    5555555555  registered


\echo test14
DELETE FROM Registrations WHERE student='6666666666' AND course='CCC333';
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- DELETE 1
-- course       student  status        position
-----------  ----------  ----------  ----------
-- CCC222    2222222222  waiting              1
-- CCC222    6666666666  registered
-- CCC333    1111111111  waiting              2
-- CCC333    2222222222  registered
-- CCC333    3333333333  registered
-- CCC333    5555555555  waiting              1
-- CCC444    5555555555  registered


\echo test15
DELETE FROM Registrations WHERE student='3333333333' AND course='CCC333';
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- DELETE 1
-- course       student  status        position
-----------  ----------  ----------  ----------
-- CCC222    2222222222  waiting              1
-- CCC222    6666666666  registered
-- CCC333    1111111111  waiting              1
-- CCC333    2222222222  registered
-- CCC333    5555555555  registered
-- CCC444    5555555555  registered


\echo test16
DELETE FROM Registrations WHERE student='5555555555' AND course='CCC333';
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- DELETE 1
-- course       student  status        position
-----------  ----------  ----------  ----------
-- CCC222    2222222222  waiting              1
-- CCC222    6666666666  registered
-- CCC333    1111111111  registered
-- CCC333    2222222222  registered
-- CCC444    5555555555  registered


\echo test17
DELETE FROM Registrations WHERE student='1111111111' AND course='CCC333';
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- DELETE 1
-- course       student  status        position
-----------  ----------  ----------  ----------
-- CCC222    2222222222  waiting              1
-- CCC222    6666666666  registered
-- CCC333    2222222222  registered
-- CCC444    5555555555  registered


\echo test18
INSERT INTO Registrations VALUES ('2222222222', 'CCC111');
SELECT course, student, status, position
FROM Registrations NATURAL LEFT JOIN WaitingList
ORDER BY (course, student);
-- course       student  status        position
-----------  ----------  ----------  ----------
-- CCC111    2222222222  registered
-- CCC222    2222222222  waiting              1
-- CCC222    6666666666  registered
-- CCC333    2222222222  registered
-- CCC444    5555555555  registered
