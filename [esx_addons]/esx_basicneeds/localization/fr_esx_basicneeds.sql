-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

INSERT INTO `items` (`name`, `label`, `weight`) VALUES
	('bread', 'Pain', 1),
	('water', 'Eau', 1)
;

INSERT INTO `items` (`name`, `label`, `weight`) VALUES
    ('beer', 'Bière', 1)
;

INSERT INTO `shops` (store, item, price) VALUES
    ('TwentyFourSeven', 'beer', 45),
    ('RobsLiquor', 'beer', 45),
    ('LTDgasoline', 'beer', 45)
;
