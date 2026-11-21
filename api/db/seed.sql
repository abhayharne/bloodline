-- Demo seed (coordinates around Nagpur, India; change freely)
DELETE FROM request_members; DELETE FROM requests; DELETE FROM bank_stock; DELETE FROM users;

INSERT INTO users (id,name,role,blood_group,lat,lng) VALUES
 ('ureq1','Ravi','requester','O-',21.1458,79.0882),
 ('udon1','Asha','donor','O-',21.1500,79.0900),
 ('udon2','Imran','donor','O-',21.1300,79.0700),
 ('udon3','Priya','donor','O+',21.1600,79.1000),
 ('udon4','Karan','donor','A+',21.1400,79.0800),
 ('udon5','Meera','donor','O-',21.2500,79.2000),
 ('ubank1','City Blood Bank','bank',NULL,21.1480,79.0850),
 ('ubank2','Lifeline Blood Centre','bank',NULL,21.1200,79.0600);

INSERT INTO bank_stock (bank_id,blood_group,units) VALUES
 ('ubank1','O-',1),('ubank1','O+',6),('ubank1','A+',4),('ubank1','B+',3),
 ('ubank2','O-',0),('ubank2','O+',2),('ubank2','AB+',1);
