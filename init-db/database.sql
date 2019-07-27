CREATE TABLE hardware (
  id INT AUTO_INCREMENT,
  provider TEXT NOT NULL,
  name TEXT NOT NULL,
  PRIMARY KEY (id)
);

INSERT INTO hardware(provider, name) VALUES ('Amazon', 'c5');
INSERT INTO hardware(provider, name) VALUES ('Azure', 'H16mr');