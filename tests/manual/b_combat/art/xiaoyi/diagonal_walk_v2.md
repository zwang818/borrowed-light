# 灰盒斜向步态 v2

素材：`xiaoyi_diagonal_walk_v2.png`。2026-11-07 使用内置 image_gen，参考现有 `xiaoyi_body_rig.png` 生成。透明 PNG，8列×3行，依次为左下、左上、右下。

仅由 `xiaoyi_graybox_visual.gd` 使用。运行时截取髋部以下腿部帧；头部、躯干和武器臂保持现有素材。采用上半身轮廓定位，避免脚步改变外接框引起水平抖动。右上和主场景不受影响。停步及死亡恢复原站姿。

生成提示词：

Use case: precise-object-edit. Create a production game sprite sheet from the supplied robot body rig reference. Output transparent PNG, exactly 8 equal columns x 3 equal rows. Each cell contains one full robot WITHOUT ARMS (shoulder round sockets only, as reference). Row 1 faces down-left (front three-quarter, reference row 2); row 2 faces up-left (back three-quarter, reference row 4); row 3 faces down-right (front three-quarter, reference row 8). All 8 cells in each row are sequential walk cycle frames, NOT different camera views. Preserve robot identity, exact head/torso shape, antenna, armor colors and backpack. Head and torso must remain IDENTICAL between frames within each row, same scale, same pixel position, no bob, no turning. Change only hip-to-foot pose. Draw natural alternating left/right leg walking with bent knees, clear passing poses and planted feet. 8 frames: left forward contact, left support/right lift, passing right knee bent, right forward approach, right forward contact, right support/left lift, passing left knee bent, left forward approach. Small controlled robot steps, not running, not skating, not both feet advancing together. Left-up rear view must show back of heels and correct occlusion; front-left/front-right show toes with correct perspective, don't reuse rear feet for front views. Feet must remain separate, retain boot volume; no stretching or pointed feet. Match the reference pixel-art rendering and proportions. Equal grid cells with generous transparent gutters and feet aligned to one ground baseline per row, consistent robot size all cells. No text, no grid lines, no shadows, no weapons, no added arms. This is a walk cycle animation asset, prioritize precise sequential leg motion and consistent upper body.

## 步频与前斜向调整

左下保留原八帧循环和64像素周期。左上改为104像素周期（在96像素版本上再放慢约8%），身体重心起伏同步放慢。右下仅腿部采用左下已认可循环的水平对称版本，躯干、头部和武器臂不镜像；未替换共享素材或主场景代码。
