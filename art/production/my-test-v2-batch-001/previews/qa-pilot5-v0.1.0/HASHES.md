# Pilot5 QA hash record

- tested_revision (assets+assembly under test): `3170da1789a87fc5bd83218cef6eb3321f4cb03e`
- reviewer: 奇幻兄弟·QA
- date: 2026-09-22

## Assembly package
- path: `art/production/my-test-v2-batch-001/exports/assembly/assembly-v0.1.0-pilot5.json`
- sha256: `233e500d8735fdfac023927b74c33e836d6f6535bb1432b5075aab151a1087de`
- expected: `233e500d8735fdfac023927b74c33e836d6f6535bb1432b5075aab151a1087de`
- match: True
- transform_policy: `resolved_once`
- assembly_revision: `assembly-v0.1.0-pilot5`

## Pilot part PNGs (file = card = assembly)
- `head_001.main` `f7145a791ce07bd49d142b67aed9c47d8bef25c61c9fc4714ceeadb0a2c1c887` match_assembly=True bytes=356464
- `padded_001_intact.main` `da6fd08c699860c317257e8ae4d4de661643d597e549d42308224831ad5a9eec` match_assembly=True bytes=622215
- `padded_001_damaged.main` `219518a39035363a02fdf6cb4e44bd78c7e1e291c7e86cad80c278fa9d7bc7d7` match_assembly=True bytes=639142
- `sword_001.main` `658319b01899adb811bd518f9c4334e6f29a33a0ea3f5a55f89dd7b467c3e3b3` match_assembly=True bytes=143355
- `headgear_metal_001.back` `5ee3a053d085d01e89ce7edaa0fa673579a785c281d32ddabf9c39e70669b35c` match_assembly=True bytes=379937
- `headgear_metal_001.main` `0f0d75cbe9819a11568f8382a6955b7e50d210f3b094743b424c541828627a3f` match_assembly=True bytes=390371
- `headgear_metal_001.front` `5d3eb0a4d638269baebe0fd89f92e231cfdaa0a5685ba33255e7b456eac1d9c4` match_assembly=True bytes=257968

## Protected baseline (T10)
- `my_test-v2.json` `da687e7979965d4ffa0b272f4358fdeee74b5310f9af0756da6ba71b1fc836f7` match=True
- `game/assets/art/static-bust/catalog.json` `b411dfd57a4efb9bbf1c866f2d37f8dbfbc351d838431da5403719e1c678123e` match=True
- `game/assets/art/static-bust/modules.json` `9976573dc1f5fbcbfe1936cbb261970a5b49ae24569ef3e961cff71cd9e017b5` match=True
- `game/presentation/static_bust_motion.gd` `4ba07127fc56e17be5bce33234ac94d7d73976618b374357b4d1c6eea75bae11` match=True
- `game/presentation/static_bust_actor.gd` `3174630822198903bf7338ee59202a00d800696dabb801d5aa068f1e8d1410ea` match=True
- `game/presentation/paperdoll_document.gd` `ea3ac726dbd97d8aa8d650306d4fc72d9612e8dee0d2d434e0fd23076ec6388e` match=True
- `game/assets/art/static-bust/anatomy.png` `31597055fae25590baaea0da922a694679d6934cec1e742f53798006fa6afcfb` match=True
- `game/assets/art/static-bust/body-head.png` `c6e08f6464e945ad31737bb1398299a04b8e31ad44ddf4bd3186011237c4c5c4` match=True
- `game/assets/art/static-bust/body-mild-proof.png` `579423add4e0e8e635f05d35ea17c88cc1e53a526b09aa139d5b39904316590a` match=True
- `game/assets/art/static-bust/full-damaged-nested.png` `9f9662b6c8bc757c9c4bca8c6738151179160bf8596527e1c8001210dd865dc5` match=True
- `game/assets/art/static-bust/full-garments-nested.png` `02958d8152205e4ac3e7ed6496dfc93f93a1fd805ee823ae7c28ad386a67ae40` match=True
- `game/assets/art/static-bust/full-garments.png` `1de50fae31aa09261cf462318e2a88f2b73cc97affb90b7cb90675dc1969402c` match=True
- `game/assets/art/static-bust/modular-proof.png` `932e0d5b21b2002f82ca42d549598517715938bc708d1012697b74650baa52bc` match=True
- `game/assets/art/static-bust/weapons.png` `74847bd0aee0bf5ae753e90863b8ddb2d94ab32acb7e4c87833310fee5fdc4c9` match=True

Note: `static_bust_actor.gd` matches the post-assembly manifest hash, not the stage-0 hash `435ab093…` (assembler added headgear draw; that change predates this QA). QA did not overwrite my_test-v2 / catalog / modules / original baseline art.

