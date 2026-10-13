// Cursor trail for Ghostty
//
// Use tmux 3.8 or later. Older tmux (confirmed with 3.7c) moves the real cursor
// while an application is redrawing inside synchronized output, so this shader
// sees those intermediate positions and draws trails all over the screen.

// Configurations
// 長さの単位: カーソルの高さ (1.0 = カーソル1個分)
const float MIN_DISTANCE = 1.5;  // Trailを出力する最小の移動距離 (長さ)
const float TRAIL_RATIO = 0.8;   // 移動距離に対するTrailの長さの割合 (0〜1)
const float SPEED = 23.0;        // Trailがカーソルまで 1.0 の距離に近づいたときの速さ (長さ/秒)
const float SLOWDOWN = 0.95;     // 減速度合い (0〜1未満、0 で等速)

// 中心 c、半分の大きさ h の長方形までの符号付き距離。内側が負になる。
float sdBox(vec2 p, vec2 c, vec2 h) {
    vec2 d = abs(p - c) - h;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// 四角形までの符号付き距離。内側が負になる。

float sdQuad(vec2 p, vec2 v[4]) {
    float d = dot(p - v[0], p - v[0]);
    float s = 1.0;
    for (int i = 0, j = 3; i < 4; j = i, i++) {
        vec2 e = v[j] - v[i];
        vec2 w = p - v[i];
        vec2 b = w - e * clamp(dot(w, e) / max(dot(e, e), 1e-6), 0.0, 1.0);
        d = min(d, dot(b, b));
        bvec3 c = bvec3(p.y >= v[i].y, p.y < v[j].y, e.x * w.y > e.y * w.x);
        if (all(c) || all(not(c))) s = -s;
    }
    return s * sqrt(d);
}

// cursor.xy は左端と +Y 側の端。y の向きは環境で異なる (macOS の Metal は下向き) が、
// 中心はどちらでもこの式で求まる。
vec2 center(vec4 cursor) {
    return cursor.xy + vec2(cursor.z, -cursor.w) * 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);

    vec4 cur = iCurrentCursor;
    vec2 head = center(cur);
    vec2 size = cur.zw * 0.5;
    vec2 move = head - center(iPreviousCursor);
    if (length(move) < cur.w * MIN_DISTANCE) return;

    // 尻尾の長さ (カーソルの高さ単位) と、縮みきるまでの秒数。
    // 縮む速さは「残りの長さの SLOWDOWN 乗 × SPEED」。
    // 遠くへ飛ぶほど長くかかるが、縮み始めが速いので距離ほどには時間が伸びない。
    float dist = length(move) * TRAIL_RATIO / cur.w;
    float runTime = pow(dist, 1.0 - SLOWDOWN) / ((1.0 - SLOWDOWN) * SPEED);
    float t = iTime - iTimeCursorChange;
    if (t >= runTime) return;

    // 今のカーソルの上は塗らない。カーソル本体の描画をそのまま見せる。
    if (sdBox(fragCoord, head, size) < 0.0) return;

    // カーソルが先に着地し、尻尾がすぐに縮み始める。
    // 短くなるほどゆっくり縮む。
    float remain = pow(1.0 - t / runTime, 1.0 / (1.0 - SLOWDOWN));
    vec2 tail = head - move * TRAIL_RATIO * remain;

    // カーソルの四角形が tail から head まで動いた軌跡を描く。
    // tail の四角形と、両者を結ぶ帯の組み合わせになる。
    // 帯の両端は、進行方向に垂直な向きで一番外側にある点 (斜めなら角、真横や真上なら辺の中点)。
    vec2 edge = sign(vec2(-move.y, move.x)) * size;
    vec2 band[4] = vec2[4](tail + edge, head + edge, head - edge, tail - edge);

    // 縁の1ピクセルでなめらかに薄くする
    float d = min(sdBox(fragCoord, tail, size), sdQuad(fragCoord, band));
    float alpha = clamp(0.5 - d, 0.0, 1.0) * iCurrentCursorColor.a;

    // カーソル色はそのまま使う。macOS の初期設定 (alpha-blending = native) では、
    // 画面と同じ色空間で渡される。linear 系の設定では色がずれる。
    fragColor.rgb = mix(fragColor.rgb, iCurrentCursorColor.rgb, alpha);
}
