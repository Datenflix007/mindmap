window.MM = (() => {
  const $ = (s, r=document) => r.querySelector(s);
  const $$ = (s, r=document) => [...r.querySelectorAll(s)];
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
  const q = k => new URLSearchParams(location.search).get(k);
  const fmt = d => new Date(d).toLocaleString('de-DE',{dateStyle:'short',timeStyle:'short'});
  const toast = (msg, type='ok') => {
    const el=document.createElement('div'); el.textContent=msg;
    Object.assign(el.style,{position:'fixed',right:'18px',bottom:'18px',zIndex:9999,padding:'12px 16px',borderRadius:'12px',background:type==='error'?'#c84d58':'#0d3d49',color:'#fff',boxShadow:'0 8px 30px rgba(0,0,0,.2)',fontWeight:'700',maxWidth:'420px'});
    document.body.appendChild(el); setTimeout(()=>el.remove(),3200);
  };
  const configuredGuard = () => { if(window.APP_CONFIGURED) return true; toast('Supabase ist noch nicht konfiguriert. Siehe README.md.', 'error'); return false; };

  function svgLayout(title, branches, nodes, opts={}){
    const allGroups = opts.showGroups !== false;
    const W = Math.max(1200, 920 + nodes.length*8), branchGap=190, rootX=70, branchX=300, nodeX=580;
    const rows = branches.map((b,i)=>({b,y:100+i*branchGap}));
    const positions = new Map();
    const childrenOf = id => nodes.filter(n=>String(n.parent_id||'')===String(id||''));
    const branchNodes = b => nodes.filter(n=>String(n.branch_id)===String(b.id) && !n.parent_id);
    let maxY = 160;
    function assignChildren(parentId, depth, baseY){
      const kids=childrenOf(parentId); let y=baseY;
      kids.forEach((n,idx)=>{const py=y+idx*72;positions.set(n.id,{x:nodeX+depth*230,y:py});assignChildren(n.id,depth+1,py+48);maxY=Math.max(maxY,py+70)});
    }
    rows.forEach(({b,y})=>{let cursor=y-52;branchNodes(b).forEach((n,idx)=>{const py=cursor+idx*84;positions.set(n.id,{x:nodeX,y:py});assignChildren(n.id,1,py+44);maxY=Math.max(maxY,py+70)});});
    const H=Math.max(560,maxY+90,branches.length*branchGap+80);
    let s=`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><defs><filter id="sh"><feDropShadow dx="0" dy="3" stdDeviation="4" flood-opacity=".12"/></filter></defs><rect width="100%" height="100%" fill="#fbfefe"/><text x="${rootX}" y="${H/2}" font-family="Inter,Arial" font-size="24" font-weight="800" fill="#0d3d49">${esc(title)}</text>`;
    rows.forEach(({b,y},i)=>{
      const cy=y; s+=`<path d="M ${rootX+170} ${H/2} C ${rootX+220} ${H/2}, ${branchX-70} ${cy}, ${branchX} ${cy}" fill="none" stroke="#45c6cd" stroke-width="4"/>`;
      s+=`<rect x="${branchX}" y="${cy-31}" rx="14" width="220" height="62" fill="#eef8c9" stroke="#c8e967" stroke-width="2" filter="url(#sh)"/><text x="${branchX+18}" y="${cy+6}" font-family="Inter,Arial" font-size="18" font-weight="800" fill="#23434b">${esc(b.title)}</text>`;
      branchNodes(b).forEach(n=>{const p=positions.get(n.id); if(!p)return; s+=`<path d="M ${branchX+220} ${cy} C ${branchX+260} ${cy}, ${p.x-40} ${p.y}, ${p.x} ${p.y}" fill="none" stroke="#9ac7cd" stroke-width="3"/>`;});
    });
    nodes.forEach(n=>{if(n.parent_id){const p=positions.get(n.id),pp=positions.get(n.parent_id);if(p&&pp)s+=`<path d="M ${pp.x+190} ${pp.y} C ${pp.x+220} ${pp.y}, ${p.x-40} ${p.y}, ${p.x} ${p.y}" fill="none" stroke="#b9ced2" stroke-width="2.5"/>`;}});
    nodes.forEach(n=>{const p=positions.get(n.id); if(!p)return; const text=String(n.text||''); const line1=text.length>28?text.slice(0,28)+'…':text; s+=`<g data-node-id="${esc(n.id)}" class="mind-node" style="cursor:pointer"><rect x="${p.x}" y="${p.y-28}" rx="12" width="190" height="56" fill="#fff" stroke="#cfe1e5" stroke-width="2" filter="url(#sh)"/><text x="${p.x+14}" y="${p.y+5}" font-family="Inter,Arial" font-size="14" font-weight="700" fill="#173942">${esc(line1)}</text>`; if(allGroups && n.group_no) s+=`<rect x="${p.x+145}" y="${p.y-23}" rx="8" width="36" height="22" fill="#7162e7"/><text x="${p.x+163}" y="${p.y-7}" text-anchor="middle" font-family="Inter,Arial" font-size="11" font-weight="900" fill="#fff">G${esc(n.group_no)}</text>`; s+='</g>';});
    s+='</svg>'; return s;
  }

  function downloadBlob(blob,name){const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=name;document.body.appendChild(a);a.click();setTimeout(()=>{URL.revokeObjectURL(a.href);a.remove()},1200)}
  function exportSVG(svgEl, name='mindmap.svg'){ const xml=new XMLSerializer().serializeToString(svgEl); downloadBlob(new Blob([xml],{type:'image/svg+xml;charset=utf-8'}),name); }
  async function svgToCanvas(svgEl, scale=2){
    const xml=new XMLSerializer().serializeToString(svgEl), blob=new Blob([xml],{type:'image/svg+xml'}), url=URL.createObjectURL(blob); const img=new Image();
    await new Promise((res,rej)=>{img.onload=res;img.onerror=rej;img.src=url}); const c=document.createElement('canvas');c.width=svgEl.viewBox.baseVal.width*scale;c.height=svgEl.viewBox.baseVal.height*scale;const ctx=c.getContext('2d');ctx.fillStyle='#fff';ctx.fillRect(0,0,c.width,c.height);ctx.drawImage(img,0,0,c.width,c.height);URL.revokeObjectURL(url);return c;
  }
  async function exportJPG(svgEl,name='mindmap.jpg'){const c=await svgToCanvas(svgEl,2);c.toBlob(b=>downloadBlob(b,name),'image/jpeg',.94)}
  async function exportPDF(svgEl,name='mindmap.pdf'){if(!window.jspdf){toast('PDF-Bibliothek konnte nicht geladen werden.','error');return}const c=await svgToCanvas(svgEl,1.7),img=c.toDataURL('image/jpeg',.93);const {jsPDF}=window.jspdf;const landscape=c.width>=c.height;const pdf=new jsPDF({orientation:landscape?'landscape':'portrait',unit:'pt',format:'a4'});const pw=pdf.internal.pageSize.getWidth(),ph=pdf.internal.pageSize.getHeight();const r=Math.min((pw-36)/c.width,(ph-36)/c.height);pdf.addImage(img,'JPEG',18,18,c.width*r,c.height*r);pdf.save(name)}
  return {$,$$,esc,q,fmt,toast,configuredGuard,svgLayout,exportSVG,exportJPG,exportPDF,downloadBlob};
})();
