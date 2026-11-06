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
    // streamline's per-point radius (interpolated at the ring), giving a
    // variable-radius tube. Colour is a per-vertex `color` attribute sampled
    // from the per-point colours at the same ring. Returns a Group.
    function buildTubes(x, transparent) {
      const group = new THREE.Group();
      const radial = 6;
      const pos = b64ToF32(x.positions);  // per-point xyz
      const col = b64ToU8F32(x.colors);    // per-point rgb (0-1)
      const rad = b64ToF32(x.radii);       // per-point radius
      const off = x.tubeOffsets; // cumulative point index
      // Tubes are fill tubes shaded with a real Phong material in FlatShading
      // mode (phantomas-style, see MeshSource.js: FlatShading + DoubleSide),
      // lit by the scene's ambient + directional lights, so densely-packed
      // tubes stay legible without an opaque border masking the fill. An
      // optional slim outline is still available:
      // `border` is a fraction of the scene radius (a CONSTANT pixel width
      // that does not vanish on thin strands), drawn as an OPAQUE black tube
      // at radius + dw (built first) so the rim survives transparent-object
      // sorting. It defaults to 0 (off); set it positive in the payload to
      // enable a border.
      const border = (typeof x.border === 'number' && x.border >= 0) ? x.border : 0;
      const dw = border * sceneRadius(pos);

      for (let t = 0; t < off.length - 1; t++) {
        const a = off[t], b = off[t + 1];
        const n = b - a;                 // points in this streamline
        if (n < 2) continue;
        const pts = [];
        for (let i = a; i < b; i++) pts.push(new THREE.Vector3(pos[3*i], pos[3*i+1], pos[3*i+2]));
        const curve = new THREE.CatmullRomCurve3(pts);

        // tubular segments ~ one per point (capped) so rings align with points;
        // unit radius, displaced below.
        const tubular = Math.min(64, Math.max(8, n));
        const fillMat = new THREE.MeshPhongMaterial({
          vertexColors: true,
          flatShading:  true,   // phantomas-style per-facet shading
          side:         THREE.DoubleSide,
          transparent:  transparent,
          opacity:      x.opacity,
          depthWrite:   false
        });

        if (dw > 0) {
          // Opaque black outline hull: same radial displacement, offset by +dw.
          const outer = new THREE.TubeGeometry(curve, tubular, 1, radial, false);
          displaceTubes(outer, radial, tubular, pos, col, rad, a, n, dw, [0, 0, 0]);
          group.add(new THREE.Mesh(outer, new THREE.MeshBasicMaterial({
            color: 0x000000
          })));
        }

        const geo = new THREE.TubeGeometry(curve, tubular, 1, radial, false);
        displaceTubes(geo, radial, tubular, pos, col, rad, a, n, 0, null);
        group.add(new THREE.Mesh(geo, fillMat));
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
        renderer.dispose();
        controls.dispose();
        if (renderer.domElement.parentNode) {
          renderer.domElement.parentNode.removeChild(renderer.domElement);
        }
      },

      renderValue: function(x) {
        scene.background = new THREE.Color(x.bg);

        if (mesh) {
          scene.remove(mesh);
          disposeObject(mesh);
          mesh = null;
          cameraFrame = null;
        }

        const transparent = x.opacity < 1;

        // ---- tube mode: variable per-point radius ----------------------------
        if (x.mode === 'tube' || (x.radii && x.tubeOffsets)) {
          mesh = buildTubes(x, transparent);
        // ---- line2 mode: constant world-width lines (default) ----------------
        } else {
          mesh = buildLine2(x, transparent);
        }

        scene.add(mesh);
        frameCamera(b64ToF32(x.positions));
      },

      sizing: {},
      instanceMethods: {}
    };
  }
});
