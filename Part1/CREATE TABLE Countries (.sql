CREATE TABLE Countries (
    name TEXT PRIMARY KEY ,
    abbr CHAR(2),
    capital TEXT,
    area FLOAT,
    populazion INT NOt NULL CHECK (populazion>0));


drop table Countries;

INSERT INTO Countries
VALUES ('ffff','FR','paris',123,1000000);
