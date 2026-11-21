-- Demo seed (coordinates around Nagpur, India; change freely)
DELETE FROM request_members; DELETE FROM requests; DELETE FROM bank_stock; DELETE FROM users;

INSERT INTO users (id,name,role,blood_group,lat,lng) VALUES
 ('u_req1','Ravi','requester','O-',21.1458,79.0882),
 ('u_don1','Asha','donor','O-',21.1500,79.0900),
 ('u_don2','Imran','donor','O-',21.1300,79.0700),
 ('u_don3','Priya','donor','O+',21.1600,79.1000),
 ('u_don4','Karan','donor','A+',21.1400,79.0800),
 ('u_don5','Meera','donor','O-',21.2500,79.2000),
 ('u_bank1','City Blood Bank','bank',NULL,21.1480,79.0850),
 ('u_bank2','Lifeline Blood Centre','bank',NULL,21.1200,79.0600);

INSERT INTO bank_stock (bank_id,blood_group,units) VALUES
 ('u_bank1','O-',1),('u_bank1','O+',6),('u_bank1','A+',4),('u_bank1','B+',3),
 ('u_bank2','O-',0),('u_bank2','O+',2),('u_bank2','AB+',1);
