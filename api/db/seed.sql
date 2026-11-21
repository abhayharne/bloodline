-- Demo seed (coordinates around Nagpur, India; change freely)
-- Used by POST /dev/reset (DEV=1). All ids are alphanumeric for Nexconn.
-- Delete dependants before their parents so foreign keys stay valid.
DELETE FROM notifications;
DELETE FROM donations;
DELETE FROM request_members;
DELETE FROM requests;
DELETE FROM bank_stock;
DELETE FROM users;

INSERT INTO users
  (id,name,role,blood_group,lat,lng,phone,sex,age,weight_kg,height_cm,
   donated_before,last_donated_at,available,consent_at)
VALUES
  ('ureq1','Ravi','requester','O-',21.1458,79.0882,'+919999900001',NULL,NULL,NULL,NULL,0,NULL,1,'2026-11-22 09:00:00'),
  ('udon1','Asha','donor','O-',21.1500,79.0900,'+919999900002','female',28,58,163,0,NULL,1,'2026-11-22 09:00:00'),
  ('udon2','Imran','donor','O-',21.1300,79.0700,'+919999900003','male',35,70,175,1,'2025-06-01',1,'2026-11-22 09:00:00'),
  ('udon3','Priya','donor','O+',21.1600,79.1000,'+919999900004','female',31,60,165,0,NULL,1,'2026-11-22 09:00:00'),
  ('udon4','Karan','donor','A+',21.1400,79.0800,'+919999900005','male',42,75,178,1,'2025-03-10',1,'2026-11-22 09:00:00'),
  ('udon5','Meera','donor','O-',21.2500,79.2000,'+919999900006','female',26,52,160,0,NULL,1,'2026-11-22 09:00:00'),
  ('ubank1','City Blood Bank','bank',NULL,21.1480,79.0850,'+919999900007',NULL,NULL,NULL,NULL,0,NULL,1,'2026-11-22 09:00:00'),
  ('ubank2','Lifeline Blood Centre','bank',NULL,21.1200,79.0600,'+919999900008',NULL,NULL,NULL,NULL,0,NULL,1,'2026-11-22 09:00:00');

INSERT INTO bank_stock (bank_id,blood_group,units) VALUES
  ('ubank1','O-',1),('ubank1','O+',6),('ubank1','A+',4),('ubank1','B+',3),
  ('ubank2','O-',0),('ubank2','O+',2),('ubank2','AB+',1);

-- One open request with its room pre-created by the dev reset.
INSERT INTO requests (id,requester_id,blood_group,units,hospital,urgency,lat,lng,status,channel_id)
VALUES ('rseed1','ureq1','O-',2,'City Hospital','critical',21.1458,79.0882,'open','reqrseed1');

INSERT INTO request_members (request_id,user_id,role) VALUES
  ('rseed1','ureq1','requester'),
  ('rseed1','ubank1','bank'),
  ('rseed1','ubank2','bank');
