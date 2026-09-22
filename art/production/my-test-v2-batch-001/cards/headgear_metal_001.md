# ASSET_CARD · headgear_metal_001

- name: 开面铁盔
- status: registered
- owner: 奇幻兄弟·资产生产
- brief: 金属类；脸口透明，盔沿与盔体真实遮挡；首个接口样板

## Parts
- `headgear_metal_001.back` → `art/production/my-test-v2-batch-001/parts/headgear_metal_001/back.png` sha256=`5ee3a053d085d01e89ce7edaa0fa673579a785c281d32ddabf9c39e70669b35c` size=[1280, 720]
- `headgear_metal_001.main` → `art/production/my-test-v2-batch-001/parts/headgear_metal_001/main.png` sha256=`0f0d75cbe9819a11568f8382a6955b7e50d210f3b094743b424c541828627a3f` size=[1280, 720]
- `headgear_metal_001.front` → `art/production/my-test-v2-batch-001/parts/headgear_metal_001/front.png` sha256=`5d3eb0a4d638269baebe0fd89f92e231cfdaa0a5685ba33255e7b456eac1d9c4` size=[1280, 720]

## Provenance
- tool/model: Cursor.GenerateImage / cursor-generate-image
- generated_at: 2026-09-22T10:24:56+08:00
- prompt: `art/production/my-test-v2-batch-001/prompts/headgear_metal_001.md`
- raw: `art/production/my-test-v2-batch-001/sources/headgear_metal_001/main_raw.png`

## Assembly / QA
- assembly_fit: PASS `assembly-v0.1.0-pilot5`
- resolved: position [0.25, -44.5], size [58.10658, 51.11754], pivot [0.5, 1], rotation 0（back/main/front 相同）
- parent_binding: head（三片相同，表示跟随谁）
- layer_relation: back=behind_head_and_hair；main=over_hair_beard_bandage_with_face_opening；front=over_bangs_and_brow
- qa: NOT_RUN
- user_approval: PENDING
