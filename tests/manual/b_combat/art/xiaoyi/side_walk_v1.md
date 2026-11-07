# 左右侧向八帧步态

2026-11-07 使用内置 image_gen，参考 `xiaoyi_body_rig.png` 生成 `xiaoyi_side_walk_v1.png`，透明底，8列×2行（向左、向右）。仅 B 灰盒加载髋部以下的腿部帧；沿用原躯干、头部、独立武器臂。周期80世界像素，身体起伏同步。已有斜向素材和步频保持不变。

提示词：

Production 2D game sprite sheet edit based on the attached robot rig. Transparent PNG. EXACTLY 8 equal columns and 2 equal rows. Row 1: robot facing LEFT, strict side profile matching reference row 3. Row 2: facing RIGHT, strict side profile matching reference row 7. Each row is ONE seamless 8-frame WALK cycle progressing left to right. Preserve robot identity, grey weathered armor, cream face, gold ear and shoulder sockets, proportions and rendering style. NO ARMS, only shoulder sockets as in reference, no weapons. Upper body identical size, orientation and placement throughout each row. Only legs animate, natural alternating left/right feet, visible bending at knees, planted stance foot and lifting swing foot. Sequence: near foot forward contact; weight transfer/rear foot toe off; rear knee passes support leg; rear foot swings forward; far foot forward contact; near foot toe off; near knee passes support; near foot approaches contact. Clear horizontal stride in side view, small controlled steps not running, no giant kicks, preserve boot shapes. The near and far legs must exchange leading positions, not repeatedly move the same foot. Both rows toe direction matches facing. Ground baseline fixed. Each cell identical size with transparent gutters. No background, no shadow, no labels, no grid lines. Reference upper body and armor must remain consistent. Eight frames should look visibly different at leg level and connect smoothly.


向右修订：仅腿部改用向左已认可的交替动作进行水平对称，维持80像素周期；不镜像躯干、头部或武器臂。原图第二行保留，但不再用于向右运行时步态。
