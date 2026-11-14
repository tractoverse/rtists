// rtists htmlwidget for three.js r186 (ESM).
//
// Requires three.js r186 + the `examples/jsm` addons (`LineSegments2`,
// `LineSegmentsGeometry`, `LineMaterial`, `OrbitControls`) resolvable as ESM via
// an import map binding the bare specifier "three" (see rtists.yaml + the
// htmlwidget dependency setup). This module is loaded as a <script type=module>
// (or dynamically imported) so the top-level imports resolve.
//
// Two render paths, chosen by the R payload's `x.mode`:
//   * "line2"  - a single THREE.LineSegments2 with THREE.LineMaterial
//                (worldUnits:true). Constant world-space width via `linewidth`;
//                one draw call, scales to large bundles. This is the default.
//   * "tube"   - one THREE.TubeGeometry per streamline, built at unit radius and
//                radially displaced by a per-point `x.radii` array (variable
//                radius along a streamline). Colors are a per-vertex `color`
//                attribute. Object-level depth-sorted transparency via
//                transparent + depthWrite:false.
import * as THREE from 'three';
import { LineSegments2 } from './jsm/lines/LineSegments2.js';
import { LineSegmentsGeometry } from './jsm/lines/LineSegmentsGeometry.js';
import { LineMaterial } from './jsm/lines/LineMaterial.js';
import { OrbitControls } from './jsm/controls/OrbitControls.js';

// ---- binary decode helpers -------------------------------------------------
// The R payload packs positions/radii as little-endian IEEE float32 and colors
// as 8-bit channels (0-255); htmlwidgets base64-encodes the raw bytes into
// strings so the JSON stays compact for large bundles. Decode them back to the
// typed arrays the render paths expect.
function b64ToBytes(b64) {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}
// Float32 (positions, radii).
function b64ToF32(b64) {
  return new Float32Array(b64ToBytes(b64).buffer);
}
// Uint8 channels -> Float32 in [0, 1] (colors).
function b64ToU8F32(b64) {
  const bytes = b64ToBytes(b64);
  const out = new Float32Array(bytes.length);
  for (let i = 0; i < bytes.length; i++) out[i] = bytes[i] / 255;
  return out;
}

// Half the largest extent of a packed xyz positions array; used to size the
// scene-relative tube outline so it stays visible regardless of tube radius.
function sceneRadius(pos) {
  let minX = Infinity, minY = Infinity, minZ = Infinity;
  let maxX = -Infinity, maxY = -Infinity, maxZ = -Infinity;
  for (let i = 0; i < pos.length; i += 3) {
    const x = pos[i], y = pos[i+1], z = pos[i+2];
    if (x < minX) minX = x; if (x > maxX) maxX = x;
    if (y < minY) minY = y; if (y > maxY) maxY = y;
    if (z < minZ) minZ = z; if (z > maxZ) maxZ = z;
  }
  return 0.5 * Math.max(maxX - minX, maxY - minY, maxZ - minZ, 1e-6);
}

HTMLWidgets.widget({

  name: 'rtists',

  type: 'output',

  factory: function(el, width, height) {

    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(width, height);
    el.appendChild(renderer.domElement);

    // ---- hover tooltip -----------------------------------------------------
    // A lightweight DOM popup shown on pointer-move when the ray hits a line
    // or tube. Its content is rendered live on the JS side from the structured
    // payload built on the R side (`.df_tooltip_meta`): the per-point bundle
    // name and coordinates (both pinned, always shown) plus the toggleable
    // attribute columns. A right-click on the hovered tooltip opens a checkbox
    // list of all toggleable columns; toggling one updates the visible box
    // immediately. `hoverData` holds the payload for the current render and
    // `null` when the tooltip is disabled.
    const tooltip = document.createElement('div');
    tooltip.style.cssText =
      'position:fixed;pointer-events:none;z-index:10;display:none;' +
      'background:rgba(10,14,12,0.92);color:#f1eee6;' +
      'font:12px/1.45 system-ui,Segoe UI,sans-serif;padding:6px 9px;' +
      'border:1px solid rgba(241,238,230,0.25);border-radius:4px;' +
      'white-space:pre;max-width:280px;box-shadow:0 2px 8px rgba(0,0,0,0.5);';
    el.appendChild(tooltip);

    // Checkbox column-picker menu opened by right-click on the hovered tooltip.
    // Kept in its own small DOM overlay so it can be shown while the tooltip is.
    const ttMenu = document.createElement('div');
    ttMenu.style.cssText =
      'position:fixed;z-index:11;display:none;min-width:150px;' +
      'background:rgba(18,24,21,0.97);color:#f1eee6;' +
      'font:12px/1.5 system-ui,Segoe UI,sans-serif;padding:6px;' +
      'border:1px solid rgba(241,238,230,0.3);border-radius:4px;' +
      'box-shadow:0 4px 14px rgba(0,0,0,0.6);';
    el.appendChild(ttMenu);

    const raycaster = new THREE.Raycaster();
    let hoverData  = null; // { tooltipData, segToPoint, mode, positions, linewidth }
    let shownSet   = null; // Set of toggleable columns currently shown
    let hoverIdx   = -1;   // packed-point index currently hovered, or -1

    // htmlwidgets serializes a length-1 character vector as a bare JSON string
    // (jsonlite auto_unbox), so tooltipData$columns / $shown can arrive as a
    // scalar rather than an array. Normalize any such value to an array so the
    // rest of the code can always call .forEach / index into it.
    function asArray(v) { return v == null ? [] : Array.isArray(v) ? v : [v]; }

    function hideTooltip() {
      tooltip.style.display = 'none';
    }

    // Toggleable columns currently not shown (used to close the menu).
    function offColumns() {
      const cols = hoverData ? asArray(hoverData.tooltipData.columns) : [];
      return cols.filter((c) => !shownSet || !shownSet.has(c));
    }

    function closeTooltipMenu() {
      ttMenu.style.display = 'none';
      ttMenu.innerHTML = '';
    }

    // Render the tooltip text for packed-point index `idx` from the structured
    // payload: pinned bundle name, pinned XYZ line, then each shown column.
    function renderTooltip(idx) {
      if (!hoverData) return;
      const tt = hoverData.tooltipData;
      if (idx < 0 || idx >= tt.xyz.length) { hideTooltip(); return; }
      hoverIdx = idx;
      const lines = [];
      if (tt.bundle) {
        const b = tt.bundle[idx];
        if (b !== null && b !== undefined && b !== '') lines.push(b);
      }
      lines.push(tt.xyz[idx]);
      let shown = 0;
      asArray(tt.columns).forEach((c, ci) => {
        if (!shownSet.has(c)) return;
        const v = (tt.values[c] || [])[idx];
        if (v === '' || v === undefined || v === null) return;
        lines.push(c + ': ' + v);
        shown++;
      });
      if (lines.length === 0) { hideTooltip(); return; }
      tooltip.textContent = lines.join('\n');
    }

    // Position `tooltip` near a screen point, flipping across the edges so it
    // stays onscreen; shared by the hover path and the live-update re-render.
    function placeTooltip(cx, cy) {
      const px = cx + 12, py = cy + 12;
      const tw = tooltip.offsetWidth,  th = tooltip.offsetHeight;
      tooltip.style.left = (px + tw < window.innerWidth ? px : cx - tw - 12) + 'px';
      tooltip.style.top  = (py + th < window.innerHeight ? py : cy - th - 12) + 'px';
    }

    // Map a pointer-move NDC coordinate to a packed point index, or -1 when
    // nothing is hit (or the tooltip is disabled / there is no mesh yet).
    function pickPoint(mx, my) {
      if (!hoverData || !mesh) return -1;
      raycaster.setFromCamera(new THREE.Vector2(mx, my), camera);
      if (hoverData.mode === 'line2' || hoverData.segToPoint) {
        // world-units line width, plus a small scene-relative margin so thin
        // lines remain hoverable without an enormous hit region.
        raycaster.params.Line2 = {
          threshold: Math.max(hoverData.linewidth * 0.5,
                              sceneRadius(hoverData.positions) * 0.01)
        };
        const hits = raycaster.intersectObjects([mesh], false);
        if (!hits.length) return -1;
        return pointForSegment(hits[0].faceIndex, hits[0].pointOnLine);
      }
      // tube mode: a Group of per-streamline TubeGeometry meshes.
      const hits = raycaster.intersectObjects([mesh], true);
      if (!hits.length) return -1;
      return pointForTube(hits[0]);
    }

    // line2 mode: each raycast `faceIndex` is a segment index; its two
    // endpoints are packed consecutively at [2*seg*3] and [2*seg*3+3], so the
    // nearest endpoint to the hit selects the point whose metadata is shown.
    function pointForSegment(seg, hitPoint) {
      if (!hoverData.segToPoint) return -1;
      const start = hoverData.segToPoint[seg];
      if (start === undefined || start === null) return -1;
      const P  = hoverData.positions;
      const s3 = seg * 6, e3 = seg * 6 + 3;
      const ds = (P[s3]   - hitPoint.x) ** 2 + (P[s3+1]   - hitPoint.y) ** 2 + (P[s3+2]   - hitPoint.z) ** 2;
      const de = (P[e3]   - hitPoint.x) ** 2 + (P[e3+1]   - hitPoint.y) ** 2 + (P[e3+2]   - hitPoint.z) ** 2;
      return ds <= de ? start : start + 1;
    }

    // tube mode: the hit carries which streamline (userData.offset) it
    // belongs to; scan its packed points for the nearest to the hit point.
    function pointForTube(hit) {
      const off = hit.object.userData.offset;
      const cnt = hit.object.userData.count;
      if (off === undefined || cnt === undefined) return -1;
      const P = hoverData.positions;
      let best = -1, bd = Infinity;
      for (let i = 0; i < cnt; i++) {
        const dx = P[3*(off+i)]   - hit.point.x;
        const dy = P[3*(off+i)+1] - hit.point.y;
        const dz = P[3*(off+i)+2] - hit.point.z;
        const d  = dx*dx + dy*dy + dz*dz;
        if (d < bd) { bd = d; best = off + i; }
      }
      return best;
    }

    function onPointerMove(e) {
      if (!hoverData) { hideTooltip(); closeTooltipMenu(); return; }
      const rect = renderer.domElement.getBoundingClientRect();
      const mx = ((e.clientX - rect.left) / rect.width) * 2 - 1;
      const my = -(((e.clientY - rect.top) / rect.height) * 2 - 1);
      const idx = pickPoint(mx, my);
      if (idx < 0) { hideTooltip(); closeTooltipMenu(); return; }
      renderTooltip(idx);
      tooltip.style.display = 'block';
      placeTooltip(e.clientX, e.clientY);
    }

    // ---- right-click column picker -----------------------------------------
    // Render a checkbox list of every toggleable column in `hoverData`:
    // checked iff it is in `shownSet`. Toggling updates `shownSet` and
    // re-renders the tooltip of the still-hovered point in place.
    function openTooltipMenu(cx, cy) {
      if (!hoverData) return;
      const columns = asArray(hoverData.tooltipData.columns);
      ttMenu.innerHTML = '';
      const head = document.createElement('div');
      head.textContent = 'tooltip';
      head.style.cssText = 'font-weight:600;padding:0 4px 4px;' +
        'border-bottom:1px solid rgba(241,238,230,0.2);margin-bottom:4px;';
      ttMenu.appendChild(head);
      columns.forEach((c, ci) => {
        const label = document.createElement('label');
        label.style.cssText = 'display:flex;align-items:center;gap:6px;' +
          'padding:2px 4px;cursor:pointer;border-radius:3px;';
        label.title = c;
        const cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.checked = shownSet.has(c);
        cb.style.cssText = 'margin:0;accent-color:#2E7D6B;';
        cb.addEventListener('change', () => {
          if (cb.checked) shownSet.add(c);
          else shownSet.delete(c);
          // live-update: re-render the currently-hovered box, if any.
          if (hoverIdx >= 0 && hoverData) {
            renderTooltip(hoverIdx);
            tooltip.style.display = 'block';
            placeTooltip(parseInt(ttMenu.style.left, 10) || 0,
                         parseInt(ttMenu.style.top, 10) || 0);
          }
        });
        label.appendChild(cb);
        label.appendChild(document.createTextNode(c));
        ttMenu.appendChild(label);
      });
      ttMenu.style.display = 'block';
      const mw = ttMenu.offsetWidth, mh = ttMenu.offsetHeight;
      ttMenu.style.left = (cx + mw < window.innerWidth ? cx : cx - mw) + 'px';
      ttMenu.style.top  = (cy + mh < window.innerHeight ? cy : cy - mh) + 'px';
    }

    // Track pointer-down position so a right-click is distinguishable from a
    // right-drag: the latter is the OrbitControls camera pan and must not open
    // the menu.
    let pressX = -1, pressY = -1;
    function onPointerDownMenu(e) {
      pressX = e.clientX; pressY = e.clientY;
    }
    function onContextMenu(e) {
      if (!hoverData) return;
      e.preventDefault();               // suppress the native context menu
      const dx = e.clientX - pressX, dy = e.clientY - pressY;
      if (dx * dx + dy * dy > 25) return; // a drag (pan); ignore
      openTooltipMenu(e.clientX, e.clientY);
    }

    renderer.domElement.addEventListener('pointermove', onPointerMove);
    renderer.domElement.addEventListener('pointerleave', () => { hideTooltip(); });
    renderer.domElement.addEventListener('pointerdown', onPointerDownMenu);
    renderer.domElement.addEventListener('contextmenu', onContextMenu);
    // Close the menu on outside click or Escape. Kept as named handlers so
    // destroy() can remove them and avoid leaking listeners across re-renders.
    function onDocPointerDown(e) {
      if (!ttMenu.contains(e.target)) closeTooltipMenu();
    }
    function onDocKeyDown(e) {
      if (e.key === 'Escape') closeTooltipMenu();
    }
    document.addEventListener('pointerdown', onDocPointerDown);
    document.addEventListener('keydown', onDocKeyDown);


    const scene  = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(55, width / height, 0.1, 10000);

    // ---- controls ---------------------------------------------------------
    const controls = new OrbitControls(camera, renderer.domElement);

    // ---- lighting -----------------------------------------------------------
    // Phantomas-style illumination for the FlatShading fill tubes: a dim
    // ambient plus directional lights from several octants so tube facets
    // read from any viewing angle (densely-packed bundles stay legible).
    scene.add(new THREE.AmbientLight(0xffffff, 0.6));
    const dir = new THREE.DirectionalLight(0xffffff, 0.6);
    dir.position.set(1, 1, 1);
    scene.add(dir);
    const dir2 = new THREE.DirectionalLight(0xffffff, 0.3);
    dir2.position.set(-1, 1, -1);
    scene.add(dir2);
    const dir3 = new THREE.DirectionalLight(0xffffff, 0.35);
    dir3.position.set(-1, -1, 1);
    scene.add(dir3);

    // ---- spatial reference (axes at data origin, in tract units) -----------
    const axes = new THREE.AxesHelper(20);
    scene.add(axes);

    let mesh        = null;
    let cameraFrame = null;   // cached radius/center for resize
    let rafId       = null;   // requestAnimationFrame handle

    // three.js only draws when renderer.render() is called. Drive it with a
    // rAF loop so OrbitControls animate smoothly; cancel on widget removal.
    function startLoop() {
      function frame() {
        controls.update();
        renderer.render(scene, camera);
        rafId = requestAnimationFrame(frame);
      }
      cancelAnimationFrame(rafId);
      rafId = requestAnimationFrame(frame);
    }
    startLoop();

    function frameCamera(positions) {
      const n = positions.length;
      let minX = Infinity, minY = Infinity, minZ = Infinity;
      let maxX = -Infinity, maxY = -Infinity, maxZ = -Infinity;
      for (let i = 0; i < n; i += 3) {
        const x = positions[i], y = positions[i+1], z = positions[i+2];
        if (x < minX) minX = x; if (x > maxX) maxX = x;
        if (y < minY) minY = y; if (y > maxY) maxY = y;
        if (z < minZ) minZ = z; if (z > maxZ) maxZ = z;
      }
      const center = new THREE.Vector3(
        (minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2);
      const radius = Math.max(maxX - minX, maxY - minY, maxZ - minZ) * 0.5;

      cameraFrame = { center, radius: Math.max(radius, 1e-3) };
      placeCamera();
    }

    function placeCamera() {
      if (!cameraFrame) return;
      const { center, radius } = cameraFrame;
      controls.target.copy(center);
      camera.near = radius / 1000;
      camera.far  = radius * 100;
      // camera looks at center from a fixed diagonal offset
      camera.position.copy(center).add(
        new THREE.Vector3(1, 1, 1).normalize().multiplyScalar(radius * 1.6)
      );
      camera.updateProjectionMatrix();
      controls.update();
    }

    // Dispose a mesh or a Group of meshes, releasing GPU geometry/material.
    function disposeObject(obj) {
      if (!obj) return;
      if (obj.isGroup) {
        obj.traverse(function(child) {
          if (child.isMesh) {
            child.geometry.dispose();
            if (Array.isArray(child.material)) {
              child.material.forEach(function(m) { m.dispose(); });
            } else if (child.material) {
              child.material.dispose();
            }
          }
        });
      } else if (obj.geometry) {
        obj.geometry.dispose();
        if (obj.material) obj.material.dispose();
      }
    }

    // ---- line2 mode: one LineSegments2 draw call ---------------------------
    // The R payload carries interleaved [start, end] positions (6 floats per
    // segment) and per-segment vertex colours (rgb start + rgb end =
    // instanceColorStart/End, 6 floats per segment). LineMaterial(worldUnits)
    // gives a constant world-space width `linewidth`. The `resolution` uniform
    // is written automatically by LineSegments2.onBeforeRender in r186, so we
    // need not set it manually. Returns the single LineSegments2 mesh.
    function buildLine2(x, transparent) {
      const geometry = new LineSegmentsGeometry();
      geometry.setPositions(b64ToF32(x.positions));
      geometry.setColors(b64ToU8F32(x.colors));

      const material = new LineMaterial({
        color: 0xffffff,
        vertexColors: true,
        linewidth: x.linewidth,
        worldUnits: true,
        transparent: transparent,
        opacity: x.opacity,
        depthWrite: false
      });

      return new LineSegments2(geometry, material);
    }

    // ---- tube mode: per-streamline TubeGeometry + radial displacement ------
    // Each streamline becomes a unit-radius TubeGeometry around a CatmullRom
    // curve, then every ring of vertices is displaced radially by the
    // streamline's per-point radius, and coloured by a per-point `color`
    // attribute. `opt.visible` drops hidden streamlines; `opt.colors`
    // (per-point rgb) and `opt.radii` (per-point radius) override the packed
    // base arrays when the user remaps an aesthetic.
    function buildTubes(x, transparent, opt) {
      opt = opt || {};
      const group = new THREE.Group();
      const radial = 6;
      const pos = b64ToF32(x.positions);               // per-point xyz
      const col = opt.colors || b64ToU8F32(x.colors);  // per-point rgb (0-1)
      const rad = opt.radii || b64ToF32(x.radii);      // per-point radius
      const off = x.tubeOffsets; // cumulative point index
      const visible = opt.visible || null;

      const border = (typeof x.border === 'number' && x.border >= 0) ? x.border : 0;
      const dw = border * sceneRadius(pos);

      for (let t = 0; t < off.length - 1; t++) {
        if (visible && !visible[t]) continue;
        const a = off[t], b = off[t + 1];
        const n = b - a;                 // points in this streamline
        if (n < 2) continue;
        const pts = [];
        for (let i = a; i < b; i++) pts.push(new THREE.Vector3(pos[3*i], pos[3*i+1], pos[3*i+2]));
        const curve = new THREE.CatmullRomCurve3(pts);

        const tubular = Math.min(64, Math.max(8, n));
        const fillMat = new THREE.MeshPhongMaterial({
          vertexColors: true,
          flatShading:  true,
          side:         THREE.DoubleSide,
          transparent:  transparent,
          opacity:      x.opacity,
          depthWrite:   false
        });

        if (dw > 0) {
          const outer = new THREE.TubeGeometry(curve, tubular, 1, radial, false);
          displaceTubes(outer, radial, tubular, pos, col, rad, a, n, dw, [0, 0, 0]);
          group.add(new THREE.Mesh(outer, new THREE.MeshBasicMaterial({
            color: 0x000000
          })));
        }

        const geo = new THREE.TubeGeometry(curve, tubular, 1, radial, false);
        displaceTubes(geo, radial, tubular, pos, col, rad, a, n, 0, null);
        const fillMesh = new THREE.Mesh(geo, fillMat);
        fillMesh.userData.offset = a;
        fillMesh.userData.count  = n;
        group.add(fillMesh);
      }
      return group;
    }
    // Displace a unit-radius TubeGeometry per-ring by the streamline's radius,
    // and write a per-vertex colour attribute. Vertices are laid out in
    // (radial+1)-vertex rings; ring r sits at arc-length fraction r/tubular along
    // the curve (TubeGeometry samples arc-length-uniformly). Each ring's radius
    // and colour are linearly interpolated between the two polyline points that
    // bracket that arc length, so a per-point `x.radii` array displaces smoothly
    // instead of stepping point-to-point (nearest-ring).
    function displaceTubes(geo, radial, tubular, pos, col, rad, a, n, extra, solidColor) {
      const posArr = geo.attributes.position.array;
      const ringSize = radial + 1;
      const nRings = tubular + 1;
      const colorArr = new Float32Array(posArr.length); // 3 per vertex
      const center = new THREE.Vector3();
      const off    = new THREE.Vector3();

      // Cumulative arc length along the polyline points [a, a+n-1].
      const arc = new Float64Array(n);
      for (let i = 1; i < n; i++) {
        const dx = pos[3*(a+i)]   - pos[3*(a+i-1)];
        const dy = pos[3*(a+i)+1] - pos[3*(a+i-1)+1];
        const dz = pos[3*(a+i)+2] - pos[3*(a+i-1)+2];
        arc[i] = arc[i-1] + Math.sqrt(dx*dx + dy*dy + dz*dz);
      }
      const total = arc[n-1] || 1;

      for (let r = 0; r < nRings; r++) {
        // ring centre = mean of the unit ring's vertices (near curve point P)
        center.set(0, 0, 0);
        for (let j = 0; j < ringSize; j++) {
          const k = 3 * (r * ringSize + j);
          center.x += posArr[k]; center.y += posArr[k+1]; center.z += posArr[k+2];
        }
        center.divideScalar(ringSize);

        // Arc length at this ring, mapped to the bracketing polyline segment.
        const s = (r / tubular) * total;
        let p = 0;
        while (p < n - 2 && arc[p + 1] < s) p++;
        const seg = arc[p + 1] - arc[p] || 1;
        const t   = Math.max(0, Math.min(1, (s - arc[p]) / seg));
        const q   = p + 1;

        // Lerp radius and colour between the two bracketing polyline points.
        // `extra` adds a constant world offset to the radius (black outline
        // hull); `solidColor` (when non-null) overrides the per-point fill
        // colour with a constant rgb triple so the hull is monochrome.
        const radius = extra + (rad[a + p] + (rad[a + q] - rad[a + p]) * t);
        const ci = 3 * (a + p), cj = 3 * (a + q);
        let cr, cg, cb;
        if (solidColor) {
          cr = solidColor[0]; cg = solidColor[1]; cb = solidColor[2];
        } else {
          cr = col[ci]   + (col[cj]   - col[ci])   * t;
          cg = col[ci+1] + (col[cj+1] - col[ci+1]) * t;
          cb = col[ci+2] + (col[cj+2] - col[ci+2]) * t;
        }

        for (let j = 0; j < ringSize; j++) {
          const k = 3 * (r * ringSize + j);
          off.set(posArr[k]-center.x, posArr[k+1]-center.y, posArr[k+2]-center.z);
          posArr[k]   = center.x + off.x * radius;
          posArr[k+1] = center.y + off.y * radius;
          posArr[k+2] = center.z + off.z * radius;
          if (solidColor) {
            colorArr[k] = cr; colorArr[k+1] = cg; colorArr[k+2] = cb;
          } else {
            // Base vertex colour only: the Phong FlatShading material applies
            // the actual light-based shading per facet on the GPU.
            colorArr[k] = cr; colorArr[k+1] = cg; colorArr[k+2] = cb;
          }
        }
      }
      geo.attributes.position.needsUpdate = true;
      geo.setAttribute('color', new THREE.BufferAttribute(colorArr, 3));
      geo.computeVertexNormals();
    }

    // ---- legend panel + live aesthetic remapping ---------------------------
    // A toolbar toggle opens a panel that maps attributes to visual
    // aesthetics live: colour-by (bundle or any attribute column), radius-by
    // (tube mode only, any numeric attribute), and visibility toggles (per
    // bundle when a BundleName is present, else per streamline). Rebuilds the
    // mesh in place from decoded per-point buffers without re-framing the
    // camera, so the current viewpoint is preserved. The panel is available for
    // any object that carries `x.legendData` (shipped by `.df_legend_meta`).

    // Categorical palette (distinct hues) used when colouring by a string or
    // bundle attribute with several levels.
    const CAT_COLORS = [
      [230, 166, 61], [46, 125, 107], [74, 88, 153], [198, 93, 95],
      [118, 94, 150], [58, 142, 188], [222, 128, 69], [128, 186, 90],
      [201, 101, 145], [91, 145, 177], [206, 173, 84], [155, 118, 83]
    ];
    const GREY = [136, 136, 136];   // NaN / missing

    // Where the current render's selectable attributes + decoded buffers live.
    let stateX   = null;             // current render payload x
    let legendBtn  = null;           // toolbar toggle button
    let legendPanel = null;          // the panel element
    let legendState = null;          // parsed legendData (see parseLegend)

    function isNumericArr(v) {
      return v instanceof Float32Array || v instanceof Float64Array || v instanceof Int32Array || v instanceof Uint8Array;
    }
    function numericVal(v) {
      const t = typeof v;
      if (t === 'number') return v;
      if (t === 'string') { const x = parseFloat(v); return isNaN(x) ? NaN : x; }
      return NaN;
    }
    function normT(v, lo, hi) {
      if (v !== v || hi <= lo) return 0;
      return Math.max(0, Math.min(1, (v - lo) / (hi - lo)));
    }
    function rampRGB(ramp, t) {
      if (t !== t) return GREY;
      const i = Math.max(0, Math.min(255, Math.round(t * 255)));
      return [ramp[3*i], ramp[3*i+1], ramp[3*i+2]];
    }
    function categoricalColors(k) {
      const cs = [];
      for (let i = 0; i < k; i++) cs.push(CAT_COLORS[i % CAT_COLORS.length]);
      return cs;
    }
    function defaultRamp() {
      const out = new Float32Array(768);
      const c = [[230,166,61],[46,125,107],[74,88,153]];
      for (let i = 0; i < 256; i++) { const j = Math.min(2, Math.floor(i / 86)); out[3*i]=c[j][0]; out[3*i+1]=c[j][1]; out[3*i+2]=c[j][2]; }
      return out;
    }
    function registerMinMax(state, k, arr) {
      let lo = Infinity, hi = -Infinity;
      for (let i = 0; i < arr.length; i++) { const v = arr[i]; if (v === v) { if (v < lo) lo = v; if (v > hi) hi = v; } }
      state.attrMinMax[k] = [lo, hi];
    }
    function registerLevels(state, k, arr) {
      const levels = [], idx = {};
      for (let i = 0; i < arr.length; i++) {
        const key = String(arr[i]);
        if (!(key in idx)) { idx[key] = levels.length; levels.push(arr[i]); }
      }
      state.attrLevels[k] = levels;
    }

    // Parse `x.legendData` into a self-contained legendState. Numeric point
    // attributes arrive as Float32 base64 strings (compact), anything else as a
    // JSON array (a bare string for an unboxed length-1 value, treated as
    // base64-numeric).
    function parseLegend(ld) {
      if (!ld) return null;
      const npts = Array.isArray(ld.n_pts) ? ld.n_pts
                : (typeof ld.n_pts === 'object' && ld.n_pts !== null)
                    ? Object.keys(ld.n_pts).map(function (k) { return ld.n_pts[k]; })
                    : (ld.n_pts == null ? [] : [ld.n_pts]);
      const state = {
        hasLegend:    true,
        npts:         npts,
        nStreams:     npts.length,
        pointAttr:    {},
        slAttr:       {},
        attrKind:     {},
        attrIsNumeric:{},
        attrMinMax:   {},
        attrLevels:   {},
        bundleNames:  Array.isArray(ld.bundleNames) ? ld.bundleNames
                      : (ld.bundleNames == null ? [] : [ld.bundleNames]),
        slOfStreamline: [],
        ramp:         (typeof ld.ramp === 'string') ? b64ToU8F32(ld.ramp) : defaultRamp(),
        colorBy:      'default',
        radiusBy:     'default',
        visible:      npts.map(function () { return true; })
      };
      const bp = Array.isArray(ld.bundlePerSl) ? ld.bundlePerSl
                : (ld.bundlePerSl == null ? [] : [ld.bundlePerSl]);
      for (let t = 0; t < npts.length; t++) state.slOfStreamline[t] = bp[t] || 0;

      const ap = ld.attrsPoint || {};
      for (const k in ap) {
        const v = ap[k];
        if (typeof v === 'string') {
          state.pointAttr[k] = b64ToF32(v);
          state.attrKind[k] = 'point';
          state.attrIsNumeric[k] = true;
          registerMinMax(state, k, state.pointAttr[k]);
        } else if (v && Array.isArray(v)) {
          state.pointAttr[k] = v;
          state.attrKind[k] = 'point';
          state.attrIsNumeric[k] = false;
          registerLevels(state, k, v);
        }
      }
      const asl = ld.attrsSl || {};
      for (const k in asl) {
        const v = asl[k];
        if (v && Array.isArray(v)) {
          state.slAttr[k] = v;
          state.attrKind[k] = 'sl';
          state.attrIsNumeric[k] = typeof v[0] === 'number';
          if (state.attrIsNumeric[k]) registerMinMax(state, k, v);
          else registerLevels(state, k, v);
        } else {
          state.slAttr[k] = [v];
          state.attrKind[k] = 'sl';
          if (typeof v === 'number') { state.attrIsNumeric[k] = true; state.attrMinMax[k] = [v, v]; }
          else { state.attrIsNumeric[k] = false; state.attrLevels[k] = [v]; }
        }
      }
      return state;
    }

    // Colour attribute values -> per-point rgb (Float32 3/pt). Returns null
    // when `colorBy` is 'default' (caller keeps the base paint).
    function pointColorsFor(colorBy) {
      const st = legendState;
      const ramp = st.ramp;
      const n = st.npts.reduce(function (a, b) { return a + b; }, 0);
      const out = new Float32Array(3 * n);

      if (colorBy === 'Bundle') {
        const cats = categoricalColors(Math.max(1, st.bundleNames.length));
        let i = 0;
        for (let t = 0; t < st.nStreams; t++) {
          const ci = st.slOfStreamline[t];
          const c = (ci && ci > 0) ? cats[(ci - 1) % cats.length] : GREY;
          for (let k = 0; k < st.npts[t]; k++) {
            out[3*i] = c[0]/255; out[3*i+1] = c[1]/255; out[3*i+2] = c[2]/255; i++;
          }
        }
        return out;
      }

      const kind = st.attrKind[colorBy];
      if (kind === 'point') {
        const arr = st.pointAttr[colorBy];
        if (st.attrIsNumeric[colorBy]) {
          const mm = st.attrMinMax[colorBy];
          for (let p = 0; p < n; p++) {
            const c = rampRGB(ramp, normT(arr[p], mm[0], mm[1]));
            out[3*p] = c[0]; out[3*p+1] = c[1]; out[3*p+2] = c[2];
          }
        } else {
          const levels = st.attrLevels[colorBy];
          const cats = categoricalColors(levels.length);
          const cmap = {};
          for (let l = 0; l < levels.length; l++) cmap[String(levels[l])] = cats[l % cats.length];
          for (let p = 0; p < n; p++) {
            const c = cmap[String(arr[p])] || GREY;
            out[3*p] = c[0]/255; out[3*p+1] = c[1]/255; out[3*p+2] = c[2]/255;
          }
        }
        return out;
      }
      // streamline-scoped: expand the representative to every point
      const vals = st.slAttr[colorBy];
      if (st.attrIsNumeric[colorBy]) {
        const mm = st.attrMinMax[colorBy];
        let i = 0;
        for (let t = 0; t < st.nStreams; t++) {
          const c = rampRGB(ramp, normT(numericVal(vals[t]), mm[0], mm[1]));
          for (let k = 0; k < st.npts[t]; k++) { out[3*i]=c[0]; out[3*i+1]=c[1]; out[3*i+2]=c[2]; i++; }
        }
      } else {
        let i = 0;
        for (let t = 0; t < st.nStreams; t++) {
          const c = GREY;
          for (let k = 0; k < st.npts[t]; k++) { out[3*i]=c[0]/255; out[3*i+1]=c[1]/255; out[3*i+2]=c[2]/255; i++; }
        }
      }
      return out;
    }

    // Radius attribute values -> per-point radius (Float32 1/pt). Tube mode
    // only. Returns null when `radiusBy` is 'default'.
    function pointRadiiFor(radiusBy) {
      const st = legendState;
      const n = st.npts.reduce(function (a, b) { return a + b; }, 0);
      const out = new Float32Array(n);
      let bmin = Infinity, bmax = -Infinity;
      for (let i = 0; i < n && st.baseRadii; i++) {
        const v = st.baseRadii[i];
        if (v === v) { if (v < bmin) bmin = v; if (v > bmax) bmax = v; }
      }
      if (bmax <= bmin) { bmax = bmin + 1e-6; }
      const minR = bmin, maxR = bmax;
      function fill(p, v) {
        out[p] = (v !== v) ? minR : minR + normT(v, st.attrMinMax[radiusBy][0], st.attrMinMax[radiusBy][1]) * (maxR - minR);
      }
      if (st.attrKind[radiusBy] === 'point') {
        const arr = st.pointAttr[radiusBy];
        for (let p = 0; p < n; p++) fill(p, arr[p]);
      } else {
        const vals = st.slAttr[radiusBy];
        let i = 0;
        for (let t = 0; t < st.nStreams; t++) {
          const v = numericVal(vals[t]);
          for (let k = 0; k < st.npts[t]; k++) { fill(i, v); i++; }
        }
      }
      return out;
    }

    // ---- line2 rebuild ------------------------------------------------------
    // Rebuild the interleaved segment buffer honouring visibility and an
    // optional per-point colour. Returns { mesh, segToPoint, positions } so the
    // hover mapping tracks the filtered mesh.
    function buildLine2Mapped(x, visible, pointColors) {
      const fullPos = b64ToF32(x.positions);
      const fullCol = b64ToU8F32(x.colors);
      const baseSeg = x.segToPoint;
      const npts = legendState.npts;
      // skip all when legend unavailable (fallback: simple build)
      const nStreams = npts.length;

      function streamlineOf(p0) {
        let acc = 0;
        for (let t = 0; t < nStreams; t++) { if (p0 < acc + npts[t]) return t; acc += npts[t]; }
        return nStreams - 1;
      }

      const idx = [], start = [];
      for (let s = 0; s < baseSeg.length; s++) {
        const p0 = baseSeg[s];
        if (visible && !visible[streamlineOf(p0)]) continue;
        idx.push(s); start.push(p0);
      }

      const m = idx.length;
      const pos = new Float32Array(6 * m);
      const col = new Float32Array(6 * m);
      const segTP = new Int32Array(m);
      for (let j = 0; j < m; j++) {
        const s = idx[j], o = 6 * s, d = 6 * j;
        pos[d]=fullPos[o]; pos[d+1]=fullPos[o+1]; pos[d+2]=fullPos[o+2];
        pos[d+3]=fullPos[o+3]; pos[d+4]=fullPos[o+4]; pos[d+5]=fullPos[o+5];
        const p0 = start[j], p1 = p0 + 1;
        if (pointColors) {
          col[d]=pointColors[3*p0]; col[d+1]=pointColors[3*p0+1]; col[d+2]=pointColors[3*p0+2];
          col[d+3]=pointColors[3*p1]; col[d+4]=pointColors[3*p1+1]; col[d+5]=pointColors[3*p1+2];
        } else {
          col[d]=fullCol[o]; col[d+1]=fullCol[o+1]; col[d+2]=fullCol[o+2];
          col[d+3]=fullCol[o+3]; col[d+4]=fullCol[o+4]; col[d+5]=fullCol[o+5];
        }
        segTP[j] = p0;
      }

      const geometry = new LineSegmentsGeometry();
      geometry.setPositions(pos);
      geometry.setColors(col);
      const material = new LineMaterial({
        color: 0xffffff, vertexColors: true,
        linewidth: x.linewidth, worldUnits: true,
        transparent: x.opacity < 1, opacity: x.opacity, depthWrite: false
      });
      return { mesh: new LineSegments2(geometry, material), segToPoint: segTP, positions: pos };
    }

    // Rebuild the mesh in place from the current legend state. Never re-frames
    // the camera. Refreshes the hover mapping for line2.
    function rebuildMesh() {
      if (!legendState || !stateX) return;
      const x = stateX;
      const transparent = x.opacity < 1;
      const isTube = (x.mode === 'tube' || (x.radii && x.tubeOffsets));
      const visible = legendState.nStreams ? legendState.visible : null;
      let newMesh = null;

      if (isTube) {
        const cols = (legendState.colorBy !== 'default') ? pointColorsFor(legendState.colorBy) : null;
        const rads = (legendState.radiusBy !== 'default') ? pointRadiiFor(legendState.radiusBy) : null;
        newMesh = buildTubes(x, transparent,
          { colors: cols, radii: rads, visible: visible });
      } else {
        const pc = (legendState.colorBy !== 'default') ? pointColorsFor(legendState.colorBy) : null;
        const b = buildLine2Mapped(x, visible, pc);
        newMesh = b.mesh;
        if (hoverData) { hoverData.segToPoint = b.segToPoint; hoverData.positions = b.positions; }
      }

      if (mesh) { scene.remove(mesh); disposeObject(mesh); }
      mesh = newMesh;
      scene.add(mesh);
    }
    // ---- legend panel DOM + population --------------------------------------
    // Panel styles (kept in a shared cssText string so it reads like the other
    // overlays). Title, close button, colour / radius dropdowns, and a
    // visibility list (bundles when present, else one row per streamline).
    function ensureLegendDom() {
      if (legendPanel) return;
      if (!el.style.position || el.style.position === 'static') el.style.position = 'relative';

      legendBtn = document.createElement('button');
      legendBtn.type = 'button';
      legendBtn.textContent = 'Legend';
      legendBtn.style.cssText =
        'position:absolute;top:8px;right:8px;z-index:20;' +
        'background:rgba(18,24,21,0.9);color:#f1eee6;' +
        'font:11px/1 system-ui,Segoe UI,sans-serif;padding:4px 8px;' +
        'border:1px solid rgba(241,238,230,0.3);border-radius:4px;' +
        'cursor:pointer;';
      legendBtn.style.display = 'none';
      legendBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        openLegendPanel();
      });
      el.appendChild(legendBtn);

      legendPanel = document.createElement('div');
      legendPanel.style.cssText =
        'position:absolute;top:34px;right:8px;z-index:21;display:none;' +
        'min-width:210px;max-height:70%;overflow:auto;' +
        'background:rgba(18,24,21,0.97);color:#f1eee6;' +
        'font:12px/1.5 system-ui,Segoe UI,sans-serif;padding:8px;' +
        'border:1px solid rgba(241,238,230,0.3);border-radius:4px;' +
        'box-shadow:0 4px 14px rgba(0,0,0,0.6);';
      el.appendChild(legendPanel);
    }

    function closeLegendPanel() {
      if (legendPanel) legendPanel.style.display = 'none';
      if (legendBtn && legendState) legendBtn.textContent = 'Legend';
    }

    // Show a legend button only when this render carries legendData.
    function refreshLegendButton() {
      ensureLegendDom();
      legendBtn.style.display = legendState ? 'block' : 'none';
      if (!legendState) closeLegendPanel();
    }

    function openLegendPanel() {
      ensureLegendDom();
      if (!legendState || !stateX) return;
      const st = legendState;
      const isTube = (stateX.mode === 'tube' || (stateX.radii && stateX.tubeOffsets));
      const panel = legendPanel;
      panel.innerHTML = '';

      const head = document.createElement('div');
      head.style.cssText = 'font-weight:600;display:flex;justify-content:space-between;' +
        'align-items:center;border-bottom:1px solid rgba(241,238,230,0.2);' +
        'padding:0 0 4px;margin-bottom:6px;';
      const hTitle = document.createElement('span');
      hTitle.textContent = 'Legend';
      const hClose = document.createElement('button');
      hClose.type = 'button'; hClose.textContent = '\u00d7';
      hClose.style.cssText = 'background:none;border:none;color:#f1eee6;cursor:pointer;' +
        'font:14px/1 system-ui;padding:0 2px;';
      hClose.addEventListener('click', closeLegendPanel);
      head.appendChild(hTitle); head.appendChild(hClose);
      panel.appendChild(head);

      // colour-by dropdown
      panel.appendChild(selectRow('Color by', colorOptions(isTube), st.colorBy, function (v) {
        st.colorBy = v; rebuildMesh();
      }));

      // radius-by dropdown (tube mode only)
      if (isTube) {
        panel.appendChild(selectRow('Radius by', radiusOptions(), st.radiusBy, function (v) {
          st.radiusBy = v; rebuildMesh();
        }));
      }

      // visibility list
      const visHead = document.createElement('div');
      visHead.textContent = 'Show / hide';
      visHead.style.cssText = 'font-weight:600;margin:8px 0 2px;' +
        'border-top:1px solid rgba(241,238,230,0.15);padding-top:6px;';
      panel.appendChild(visHead);

      if (st.bundleNames.length) {
        st.bundleNames.forEach(function (label, ci) {
          const row = document.createElement('label');
          row.style.cssText = 'display:flex;align-items:center;gap:6px;padding:1px 2px;cursor:pointer;';
          const cb = document.createElement('input');
          cb.type = 'checkbox';
          cb.checked = true;
          cb.style.cssText = 'margin:0;accent-color:#2E7D6B;';
          cb.addEventListener('change', function () {
            setBundleVisible(ci, cb.checked);
          });
          row.appendChild(cb);
          row.appendChild(document.createTextNode(label || ('bundle ' + (ci + 1))));
          panel.appendChild(row);
        });
      } else {
        st.npts.forEach(function (cnt, t) {
          const row = document.createElement('label');
          row.style.cssText = 'display:flex;align-items:center;gap:6px;padding:1px 2px;cursor:pointer;';
          const cb = document.createElement('input');
          cb.type = 'checkbox';
          cb.checked = true;
          cb.style.cssText = 'margin:0;accent-color:#2E7D6B;';
          cb.addEventListener('change', function () {
            st.visible[t] = cb.checked; rebuildMesh();
          });
          row.appendChild(cb);
          row.appendChild(document.createTextNode('streamline ' + (t + 1)));
          panel.appendChild(row);
        });
      }

      panel.style.display = 'block';
      legendBtn.textContent = 'Legend \u00d7';
    }

    // Visibility for every streamline in bundle index ci (0-based).
    function setBundleVisible(ci, on) {
      const st = legendState;
      for (let t = 0; t < st.nStreams; t++) {
        if (st.slOfStreamline[t] === ci + 1) st.visible[t] = on;
      }
      rebuildMesh();
    }

    // Build a labelled <select> row; returns a container element.
    function selectRow(label, options, current, onChange) {
      const wrap = document.createElement('div');
      wrap.style.cssText = 'display:flex;align-items:center;justify-content:space-between;' +
        'gap:8px;margin:2px 0;';
      const lab = document.createElement('span');
      lab.textContent = label;
      const sel = document.createElement('select');
      sel.style.cssText = 'background:#0e1512;color:#f1eee6;border:1px solid rgba(241,238,230,0.25);' +
        'border-radius:3px;font:11px/1.2 system-ui;padding:1px 3px;max-width:130px;';
      options.forEach(function (o) {
        const op = document.createElement('option');
        op.value = o; op.textContent = o;
        sel.appendChild(op);
      });
      if (options.indexOf(current) < 0) current = options[0] || 'default';
      sel.value = current;
      sel.addEventListener('change', function () { onChange(sel.value); });
      wrap.appendChild(lab); wrap.appendChild(sel);
      return wrap;
    }

    function colorOptions(isTube) {
      const st = legendState;
      const seen = { 'default': 1, 'Bundle': 1 };
      const out = ['default', 'Bundle'];
      Object.keys(st.pointAttr).forEach(function (k) { if (!seen[k]) { seen[k] = 1; out.push(k); } });
      Object.keys(st.slAttr).forEach(function (k) { if (!seen[k]) { seen[k] = 1; out.push(k); } });
      return out;
    }
    function radiusOptions() {
      const st = legendState;
      const out = ['default'];
      Object.keys(st.pointAttr).forEach(function (k) { if (st.attrIsNumeric[k]) out.push(k); });
      Object.keys(st.slAttr).forEach(function (k) { if (st.attrIsNumeric[k]) out.push(k); });
      return out;
    }

    return {

      resize: function(width, height) {
        camera.aspect = width / height;
        camera.updateProjectionMatrix();
        renderer.setSize(width, height);
      },

      destroy: function() {
        cancelAnimationFrame(rafId);
        if (mesh) {
          scene.remove(mesh);
          disposeObject(mesh);
        }
        if (legendBtn && legendBtn.parentNode) legendBtn.parentNode.removeChild(legendBtn);
        if (legendPanel && legendPanel.parentNode) legendPanel.parentNode.removeChild(legendPanel);
        legendBtn = null; legendPanel = null; legendState = null; stateX = null;
        renderer.dispose();
        controls.dispose();
        if (renderer.domElement.parentNode) {
          renderer.domElement.parentNode.removeChild(renderer.domElement);
        }
        document.removeEventListener('pointerdown', onDocPointerDown);
        document.removeEventListener('keydown', onDocKeyDown);
      },

      renderValue: function(x) {
        scene.background = new THREE.Color(x.bg);

        if (mesh) {
          scene.remove(mesh);
          disposeObject(mesh);
          mesh = null;
          cameraFrame = null;
        }
        closeLegendPanel();
        closeTooltipMenu();
        hideTooltip();

        // ---- legend state for live aesthetic remapping (optional) -----------
        stateX = x;
        legendState = x.legendData ? parseLegend(x.legendData) : null;
        if (legendState) {
          const isTube = (x.mode === 'tube' || (x.radii && x.tubeOffsets));
          legendState.baseRadii = isTube ? b64ToF32(x.radii) : null;
        }
        refreshLegendButton();

        // Raycast / tooltip data for this render; null when the tooltip is off.
        hoverData = x.tooltipData ? {
          tooltipData: x.tooltipData,
          segToPoint:  x.segToPoint || null,
          mode:        x.mode,
          // line2 needs per-segment endpoints for exact nearest-point picking;
          // the legend line2 rebuild refreshes this to match a filtered mesh.
          positions:   b64ToF32(x.positions),
          linewidth:   x.linewidth
        } : null;
        shownSet = hoverData
          ? new Set(asArray(hoverData.tooltipData.shown))
          : null;
        hoverIdx = -1;

        const transparent = x.opacity < 1;
        if (legendState) {
          rebuildMesh();       // builders add the mesh to the scene
        } else if (x.mode === 'tube' || (x.radii && x.tubeOffsets)) {
          mesh = buildTubes(x, transparent);
          scene.add(mesh);
        } else {
          mesh = buildLine2(x, transparent);
          scene.add(mesh);
        }
        frameCamera(b64ToF32(x.positions));
      },

      sizing: {},
      instanceMethods: {}
    };
  }
});
