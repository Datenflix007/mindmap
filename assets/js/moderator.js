(async()=>{
 const statusEl=MM.$('#headStatus'),statusText=MM.$('#headStatusText');
 function setAppStatus(state,message){
  statusEl.className=`app-status is-${state}`;
  statusText.textContent=message;
  statusEl.title=message;
 }
 function configurationErrors(){
  const errors=[];
  if(!window.APP_CONFIGURED||!window.db) errors.push('Supabase ist nicht konfiguriert.');
  if(!window.supabase) errors.push('Die Supabase-Bibliothek konnte nicht geladen werden.');
  if(!window.QRCode) errors.push('Die QR-Code-Bibliothek konnte nicht geladen werden.');
  if(!window.jspdf) errors.push('Die PDF-Export-Bibliothek konnte nicht geladen werden.');
  return errors;
 }
 async function checkOperationalReadiness(){
  const errors=configurationErrors();
  if(errors.length){setAppStatus('error',`Fehler: ${errors.join(' ')}`);return false}
  setAppStatus('checking','Verbindung wird geprüft …');
  try{
   // Die absichtlich ungueltige Kennung veraendert nichts. Eine fehlerfreie Null-Antwort
   // bestaetigt, dass die oeffentliche Datenbankfunktion erreichbar ist.
   const {error}=await db.rpc('get_session_public',{p_code:'STATUSCHECK'});
   if(error) throw error;
  }catch(error){
   setAppStatus('error','Fehler: Supabase-Verbindung oder Datenbankschema ist nicht bereit.');
   return false;
  }
  setAppStatus('ready','Bereit zu benutzen');
  return true;
 }
 const M=MM; const DEFAULT=['Must Haves','No Gos','Anmerkung','Gern besuchte Orte']; let branchNames=[...DEFAULT],session=null,branches=[],nodes=[],token=null,poll=null;
 function renderBranchEditor(){const h=M.$('#branchEditor');h.innerHTML='<b>Vorgegebene Äste</b>';branchNames.forEach((name,i)=>{const row=document.createElement('div');row.className='branch-row';row.innerHTML=`<input value="${M.esc(name)}" data-i="${i}"><button class="btn danger" data-del="${i}">×</button>`;h.appendChild(row)});M.$$('input[data-i]',h).forEach(x=>x.oninput=e=>branchNames[+e.target.dataset.i]=e.target.value);M.$$('button[data-del]',h).forEach(x=>x.onclick=e=>{branchNames.splice(+e.currentTarget.dataset.del,1);renderBranchEditor()})}
 renderBranchEditor();
 M.$('#template').onchange=e=>{if(e.target.value==='jenacraft'){branchNames=[...DEFAULT];M.$('#title').value='Must haves und No Gos JenaCraft';renderBranchEditor()}};
 M.$('#addBranch').onclick=()=>{branchNames.push('Neuer Ast');renderBranchEditor()};
 async function createSession(){if(!M.configuredGuard())return;const title=M.$('#title').value.trim();const clean=branchNames.map(x=>x.trim()).filter(Boolean);if(!title||clean.length<1){M.toast('Titel und mindestens ein Ast werden benötigt.','error');return}M.$('#createSession').disabled=true;const {data,error}=await db.rpc('create_session',{p_title:title,p_template_key:M.$('#template').value,p_branch_titles:clean});M.$('#createSession').disabled=false;if(error){M.toast(error.message,'error');return}session=data.session;token=data.moderator_token;localStorage.setItem(`mm.mod.${session.code}`,token);await enterSession();}
 async function resume(){if(!M.configuredGuard())return;const code=M.$('#resumeCode').value.trim().toUpperCase();const tok=M.$('#resumeToken').value.trim()||localStorage.getItem(`mm.mod.${code}`);if(!code||!tok){M.toast('Code und Moderator-Schlüssel eingeben.','error');return}session={code};token=tok;await enterSession(true)}
 async function enterSession(validate=false){if(validate){const ok=await refresh(true);if(!ok)return}else await refresh(true);M.$('#createPanel').classList.add('hidden');M.$('#resumePanel').classList.add('hidden');M.$('#sessionPanel').classList.remove('hidden');M.$('#codeDisplay').textContent=session.code;M.$('#tokenDisplay').textContent=token;const url=new URL('participant.html',location.href);url.searchParams.set('session',session.code);M.$('#participantUrl').textContent=url.href;M.$('#qr').innerHTML='';new QRCode(M.$('#qr'),{text:url.href,width:220,height:220,colorDark:'#0d3d49',colorLight:'#ffffff',correctLevel:QRCode.CorrectLevel.M});poll=setInterval(refresh,2000)}
 async function refresh(initial=false){if(!session||!token)return false;const {data,error}=await db.rpc('moderator_snapshot',{p_code:session.code,p_moderator_token:token});if(error||!data){setAppStatus('error',`Fehler: ${error?.message||'Session konnte nicht geladen werden.'}`);if(initial)M.toast(error?.message||'Session konnte nicht geöffnet werden.','error');return false}session=data.session;branches=data.branches||[];nodes=data.nodes||[];const setupErrors=configurationErrors();if(setupErrors.length)setAppStatus('error',`Fehler: ${setupErrors.join(' ')}`);else setAppStatus('ready','Bereit zu benutzen');render();return true}
 function render(){M.$('#lockBtn').textContent=session.is_open?'Session sperren':'Session öffnen';const groups=[...new Set(nodes.map(n=>n.group_no))].sort((a,b)=>a-b);M.$('#statGroups').textContent=groups.length;M.$('#statNodes').textContent=nodes.length;M.$('#statBranches').textContent=branches.length;M.$('#statUpdated').textContent=new Date().toLocaleTimeString('de-DE',{hour:'2-digit',minute:'2-digit'});const sel=M.$('#groupSelect'),cur=sel.value;sel.innerHTML=groups.map(g=>`<option value="${g}">Gruppe ${g}</option>`).join('');if(cur&&groups.includes(+cur))sel.value=cur;renderMap();renderEval()}
 function filteredNodes(){if(M.$('#viewMode').value==='group'){const g=+M.$('#groupSelect').value;return nodes.filter(n=>n.group_no===g)}return nodes}
 function renderMap(){const ns=filteredNodes();M.$('#mapHost').innerHTML=M.svgLayout(session.title,branches,ns,{showGroups:M.$('#viewMode').value==='all'});M.$('#mapHost svg').classList.add('map-canvas');M.$('#mapLabel').textContent=M.$('#viewMode').value==='all'?'Gesamtmindmap (#Collect)':`Gruppe ${M.$('#groupSelect').value||'–'}`}
 function renderEval(){const groups=[...new Set(nodes.map(n=>n.group_no))].sort((a,b)=>a-b);M.$('#evalHead').innerHTML='<tr><th>Gruppe</th>'+branches.map(b=>`<th>${M.esc(b.title)}</th>`).join('')+'<th>Gesamt</th></tr>';M.$('#evalBody').innerHTML=groups.map(g=>{const counts=branches.map(b=>nodes.filter(n=>n.group_no===g&&String(n.branch_id)===String(b.id)).length);return `<tr><td><b>Gruppe ${g}</b></td>${counts.map(c=>`<td>${c}</td>`).join('')}<td><b>${counts.reduce((a,b)=>a+b,0)}</b></td></tr>`}).join('')||'<tr><td colspan="99">Noch keine Beiträge.</td></tr>'}
 M.$('#createSession').onclick=createSession;M.$('#resumeBtn').onclick=resume;M.$('#copyLink').onclick=async()=>{await navigator.clipboard.writeText(M.$('#participantUrl').textContent);M.toast('Teilnehmerlink kopiert')};
 M.$('#lockBtn').onclick=async()=>{const {error}=await db.rpc('set_session_open',{p_code:session.code,p_moderator_token:token,p_is_open:!session.is_open});if(error)M.toast(error.message,'error');else refresh()};
 M.$('#collectBtn').onclick=async()=>{M.$('#viewMode').value='all';M.$('#groupSelectWrap').classList.add('hidden');await db.rpc('mark_collected',{p_code:session.code,p_moderator_token:token});renderMap();M.toast('Alle Gruppenbeiträge wurden zur Gesamtmindmap zusammengeführt.')};
 M.$('#resetTemplateBtn').onclick=async()=>{const ok=confirm('Wirklich auf die Vorlage zurücksetzen? Alle Gruppenbeiträge dieser Session werden unwiderruflich gelöscht.');if(!ok)return;const btn=M.$('#resetTemplateBtn');btn.disabled=true;const {data,error}=await db.rpc('reset_session_to_template',{p_code:session.code,p_moderator_token:token});btn.disabled=false;if(error){M.toast(error.message,'error');return}await refresh();M.$('#viewMode').value='all';M.$('#groupSelectWrap').classList.add('hidden');M.toast(data?.message||'Mindmap wurde auf die Vorlage zurückgesetzt.');};
 M.$('#viewMode').onchange=e=>{M.$('#groupSelectWrap').classList.toggle('hidden',e.target.value!=='group');renderMap()};M.$('#groupSelect').onchange=renderMap;
 M.$('#expSvg').onclick=()=>M.exportSVG(M.$('#mapHost svg'),`${session.code}-gesamtmindmap.svg`);M.$('#expJpg').onclick=()=>M.exportJPG(M.$('#mapHost svg'),`${session.code}-gesamtmindmap.jpg`);M.$('#expPdf').onclick=()=>M.exportPDF(M.$('#mapHost svg'),`${session.code}-gesamtmindmap.pdf`);M.$('#expJson').onclick=()=>M.downloadBlob(new Blob([JSON.stringify({session,branches,nodes},null,2)],{type:'application/json'}),`${session.code}-daten.json`);
 checkOperationalReadiness();
 const code=M.q('session'); if(code){M.$('#resumePanel').classList.remove('hidden');M.$('#resumeCode').value=code.toUpperCase();const saved=localStorage.getItem(`mm.mod.${code.toUpperCase()}`);if(saved)M.$('#resumeToken').value=saved}else M.$('#resumePanel').classList.remove('hidden');
})();
