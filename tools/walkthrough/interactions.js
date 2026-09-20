const colors = { cyan:'#73ddd4', gold:'#ffd479', muted:'#a9b8cd', wall:'#354c63', ink:'#e4ecf5' };
const element = id => document.getElementById(id);
function surface(id) { const canvas=element(id); return {canvas, context:canvas.getContext('2d')}; }
function clear(context, canvas) { context.clearRect(0,0,canvas.width,canvas.height); context.font='16px system-ui'; context.lineWidth=2; }
function line(context,x1,y1,x2,y2,color,width=2) { context.strokeStyle=color;context.lineWidth=width;context.beginPath();context.moveTo(x1,y1);context.lineTo(x2,y2);context.stroke(); }
function dot(context,x,y,color,radius=5) { context.fillStyle=color;context.beginPath();context.arc(x,y,radius,0,Math.PI*2);context.fill(); }
function label(context,text,x,y,color=colors.ink) {context.fillStyle=color;context.fillText(text,x,y);}
function bindRange(id,draw) { element(id).addEventListener('input',draw);draw(); }
const mazeSurface=surface('maze-demo');
let mazeStack, mazeVisited, mazePassages, mazeMessage;
function drawMaze() {
 const {canvas,context}=mazeSurface;clear(context,canvas);
 const size=65,left=36,top=45;
 for(let row=0;row<3;row++)for(let column=0;column<4;column++){
  const key=row*4+column;context.fillStyle=mazeStack.includes(key)?'#244e55':mazeVisited.has(key)?'#22313f':'#111d2c';context.fillRect(left+column*size,top+row*size,size,size);
  context.strokeStyle=colors.wall;context.lineWidth=4;context.strokeRect(left+column*size,top+row*size,size,size);
  label(context,String(key+1),left+column*size+24,top+row*size+38);
 }
 for(const [from,to] of mazePassages){const x1=left+(from%4+.5)*size,y1=top+(Math.floor(from/4)+.5)*size,x2=left+(to%4+.5)*size,y2=top+(Math.floor(to/4)+.5)*size;line(context,(x1+x2)/2-(y1===y2?0:20),(y1+y2)/2-(x1===x2?0:20),(x1+x2)/2+(y1===y2?0:20),(y1+y2)/2+(x1===x2?0:20),'#0b1420',7);}
 if(mazeStack.length){const key=mazeStack.at(-1);dot(context,left+(key%4+.5)*size,top+(Math.floor(key/4)+.5)*size,colors.gold,8);}
 label(context,'STACK · oldest → newest',350,70,colors.cyan);
 const stackText=mazeStack.map(key=>key+1);
 label(context,stackText.slice(0,6).join(' → ')||'(empty)',350,110);
 label(context,stackText.slice(6).join(' → '),350,145);
 label(context,`${mazeVisited.size} / 12 rooms visited`,350,205,colors.gold);
 label(context,`${mazePassages.length} passages carved`,350,235,colors.muted);
 element('maze-status').textContent=mazeMessage;element('maze-step').disabled=!mazeStack.length;
}
function resetMaze(){mazeStack=[0];mazeVisited=new Set([0]);mazePassages=[];mazeMessage='Start in room 1.';drawMaze();}
function stepMaze(){
 const current=mazeStack.at(-1),column=current%4,row=Math.floor(current/4);
 const options=[[0,-1],[1,0],[0,1],[-1,0]].map(([x,y])=>[column+x,row+y]).filter(([x,y])=>x>=0&&x<4&&y>=0&&y<3).map(([x,y])=>y*4+x).filter(key=>!mazeVisited.has(key));
 if(options.length){const next=options[(mazeVisited.size*7)%options.length];mazePassages.push([current,next]);mazeVisited.add(next);mazeStack.push(next);mazeMessage=`Carve ${current+1} → ${next+1}; push ${next+1}.`;}
 else {mazeStack.pop();mazeMessage=mazeStack.length?`No unvisited neighbor; pop ${current+1}.`:'Done: 12 rooms, 11 passages, no loops.';}
 drawMaze();
}
element('maze-step').addEventListener('click',stepMaze);element('maze-reset').addEventListener('click',resetMaze);resetMaze();
const trigSurface=surface('trig-demo');
function drawTrig(){const {canvas,context}=trigSurface;clear(context,canvas);const degrees=Number(element('angle').value),angle=degrees*Math.PI/180,cosine=Math.cos(angle),sine=Math.sin(angle),x=210+110*cosine,y=150+110*sine;
 line(context,65,150,355,150,colors.wall);line(context,210,15,210,285,colors.wall);context.strokeStyle=colors.wall;context.beginPath();context.arc(210,150,110,0,Math.PI*2);context.stroke();
 line(context,210,150,x,150,colors.cyan,4);line(context,x,150,x,y,'#ef9bc6',4);line(context,210,150,x,y,colors.gold,3);dot(context,x,y,colors.gold,7);
 label(context,'+x → east',370,65);label(context,'+y ↓ south',370,98);label(context,`cos θ = ${cosine.toFixed(3)}`,410,164,colors.cyan);label(context,`sin θ = ${sine.toFixed(3)}`,410,198,'#ef9bc6');label(context,'arrow length = 1',410,242,colors.gold);
 element('angle-label').textContent=degrees+'°';element('trig-values').textContent=`Forward (${cosine.toFixed(3)}, ${sine.toFixed(3)}) · right (${(-sine).toFixed(3)}, ${cosine.toFixed(3)})`;
}
bindRange('angle',drawTrig);
const raySurface=surface('ray-demo');
const room=['11111111','10000001','10001001','10001001','10000001','11111111'];
const camera={x:2.5,y:2.5};
function cast(directionX,directionY){let gridX=Math.floor(camera.x),gridY=Math.floor(camera.y);const deltaX=directionX===0?Infinity:Math.abs(1/directionX),deltaY=directionY===0?Infinity:Math.abs(1/directionY),stepX=directionX<0?-1:1,stepY=directionY<0?-1:1;let nextX=(directionX<0?camera.x-gridX:gridX+1-camera.x)*deltaX,nextY=(directionY<0?camera.y-gridY:gridY+1-camera.y)*deltaY;const cells=[];
 while(true){const beforeX=nextX,beforeY=nextY;let depth,side;if(nextX<nextY){depth=nextX;nextX+=deltaX;gridX+=stepX;side=0;}else{depth=nextY;nextY+=deltaY;gridY+=stepY;side=1;}cells.push([gridX,gridY,depth,side,beforeX,beforeY,nextX,nextY]);if(room[gridY][gridX]==='1')return {depth,side,x:camera.x+depth*directionX,y:camera.y+depth*directionY,cells};}
}
function drawRays(){const {canvas,context}=raySurface;clear(context,canvas);const degrees=Number(element('view-angle').value),angle=degrees*Math.PI/180,selected=Number(element('ray-column').value),forwardX=Math.cos(angle),forwardY=Math.sin(angle),fieldOfView=Number(element('view-fov').value),plane=Math.tan(fieldOfView*Math.PI/360),projection=200/plane,size=40,left=15,top=45;
 label(context,'THE MAP',15,25,colors.cyan);label(context,'THE CAMERA · 400 × 240',370,25,colors.cyan);
 for(let y=0;y<6;y++)for(let x=0;x<8;x++){context.fillStyle=room[y][x]==='1'?colors.wall:'#142231';context.fillRect(left+x*size,top+y*size,size-1,size-1);}
 context.fillStyle='#182434';context.fillRect(370,45,400,120);context.fillStyle='#27323d';context.fillRect(370,165,400,120);
 for(let screenX=0;screenX<400;screenX+=4){const cameraX=2*(screenX+2)/400-1,rayX=forwardX-forwardY*plane*cameraX,rayY=forwardY+forwardX*plane*cameraX,hit=cast(rayX,rayY),height=Math.min(240,projection/Math.max(.1,hit.depth*(element('wrong-depth').checked?Math.hypot(rayX,rayY):1)));context.fillStyle=hit.side===0?'#819da4':'#b8c7c9';context.fillRect(370+screenX,165-height/2,4,height);if(screenX%32===0)line(context,left+camera.x*size,top+camera.y*size,left+hit.x*size,top+hit.y*size,'#31726e',1);}
 const cameraX=2*selected/400-1,rayX=forwardX-forwardY*plane*cameraX,rayY=forwardY+forwardX*plane*cameraX,hit=cast(rayX,rayY);
 const crossingSlider=element('ray-steps');
 const crossingCount=Math.min(Number(crossingSlider.value),hit.cells.length);
 crossingSlider.max=hit.cells.length;crossingSlider.value=crossingCount;
 const crossings=hit.cells.slice(0,crossingCount);
 for(const [index,[x,y]] of crossings.entries()){context.fillStyle='#ffd47933';context.fillRect(left+x*size,top+y*size,size-1,size-1);label(context,String(index+1),left+x*size+15,top+y*size+26,colors.gold);}
 const [crossingX,crossingY,crossingDepth,crossingSide,beforeX,beforeY,afterX,afterY]=crossings.at(-1);
 const time=value=>value>1e12?'∞':value.toFixed(3);
 element('boundary-values').textContent=`Before: x ${time(beforeX)}, y ${time(beforeY)} → choose ${crossingSide===0?'x':'y'}. After: x ${time(afterX)}, y ${time(afterY)}.`;
 element('view-fov-label').textContent=fieldOfView+'°';
 line(context,left+(camera.x+forwardX-forwardY*plane)*size,top+(camera.y+forwardY+forwardX*plane)*size,left+(camera.x+forwardX+forwardY*plane)*size,top+(camera.y+forwardY-forwardX*plane)*size,colors.cyan,3);
 const tipX=camera.x+crossingDepth*rayX,tipY=camera.y+crossingDepth*rayY;
 element('ray-steps-label').textContent=`${crossingCount} / ${hit.cells.length}`;
 element('crossing-values').textContent=`Crossing ${crossingCount}: ${crossingSide===0?'vertical (x)':'horizontal (y)'} boundary → block (${crossingX+1}, ${crossingY+1}) at t = ${crossingDepth.toFixed(3)}. ${room[crossingY][crossingX]==='1'?'Wall: stop.':'Open: continue.'}`;
 line(context,left+camera.x*size,top+camera.y*size,left+tipX*size,top+tipY*size,colors.gold,3);dot(context,left+camera.x*size,top+camera.y*size,colors.cyan,6);dot(context,left+tipX*size,top+tipY*size,colors.gold,4);
 line(context,370+selected,45,370+selected,285,colors.gold,2);label(context,'horizon',372,308,colors.muted);
 element('view-angle-label').textContent=degrees+'°';element('ray-column-label').textContent=selected;element('ray-values').textContent=`Ray (${rayX.toFixed(3)}, ${rayY.toFixed(3)}) · depth ${hit.depth.toFixed(3)} · travel ${(hit.depth*Math.hypot(rayX,rayY)).toFixed(3)} · crossed ${hit.cells.length} cells`;
}
bindRange('view-fov',drawRays);element('wrong-depth').addEventListener('change',drawRays);element('flat-wall').addEventListener('click',()=>{element('view-angle').value=180;element('view-fov').value=70;drawRays();});bindRange('view-angle',drawRays);bindRange('ray-column',drawRays);bindRange('ray-steps',drawRays);
const projectionSurface=surface('projection-demo');
function drawProjection(){const {canvas,context}=projectionSurface;clear(context,canvas);const depth=Number(element('depth').value),height=285.629601348/depth;context.fillStyle='#182434';context.fillRect(20,25,400,120);context.fillStyle='#26343d';context.fillRect(20,145,400,120);context.save();context.beginPath();context.rect(20,25,400,240);context.clip();context.fillStyle='#81a0a8';context.fillRect(160,145-height/2,120,height);context.strokeStyle=colors.gold;context.strokeRect(160,145-height/2,120,height);context.restore();line(context,20,145,420,145,colors.cyan,1);label(context,'horizon',435,150,colors.cyan);label(context,`${height.toFixed(2)} px tall`,435,195,colors.gold);label(context,'400 × 240 viewport',20,284,colors.muted);element('depth-label').textContent=depth.toFixed(1);element('projection-values').textContent=`285.63 ÷ ${depth.toFixed(1)} = ${height.toFixed(2)} pixels · top ${(120-height/2).toFixed(2)} · bottom ${(120+height/2).toFixed(2)}`;}
bindRange('depth',drawProjection);
const shadeSurface=surface('shade-demo');
function drawShade(){const {canvas,context}=shadeSurface;clear(context,canvas);const level=Number(element('shade').value),bayer=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]];for(let y=0;y<4;y++)for(let x=0;x<4;x++){const white=bayer[y][x]<level;context.fillStyle=white?'#fff':'#000';context.fillRect(20+x*36,20+y*36,34,34);label(context,String(bayer[y][x]),27+x*36,44+y*36,white?'#000':'#c7d4df');}for(let y=0;y<64;y++)for(let x=0;x<80;x++){context.fillStyle=bayer[y%4][x%4]<level?'#fff':'#000';context.fillRect(240+x*2,25+y*2,2,2);}label(context,`${level} of 16 white`,445,70,colors.gold);label(context,`${(level/16*100).toFixed(1)}% white pixels`,445,108,colors.muted);element('shade-label').textContent=level+' / 16';element('shade-values').textContent=`A pixel is white when its Bayer number is less than ${level}.`;}
bindRange('shade',drawShade);

const occlusionSurface=surface('occlusion-demo');
function drawOcclusion(){
 const {canvas,context}=occlusionSurface;clear(context,canvas);
 const depth=Number(element('sprite-depth').value),walls=Array.from({length:16},(_,index)=>index>=6&&index<=9?2:6);
 const visible=walls.map((wall,index)=>index>=2&&index<=13&&wall>depth);
 const first=visible.indexOf(true),last=visible.lastIndexOf(true);
 let extra=0;
 label(context,'Wall depth by screen column',20,30,colors.muted);
 label(context,'Per-column check: wall depth > sprite depth',20,140,colors.cyan);
 label(context,'Game: one rectangle from first to last visible column',20,250,colors.gold);
 for(let column=0;column<16;column++){
  const x=20+column*47,rectangle=first>=0&&column>=first&&column<=last;
  context.fillStyle=colors.wall;context.fillRect(x,48,44,48);label(context,String(walls[column]),x+16,79);
  context.fillStyle=visible[column]?colors.cyan:colors.wall;context.fillRect(x,158,44,48);
  context.fillStyle=rectangle?(visible[column]?colors.cyan:'#ef9bc6'):colors.wall;context.fillRect(x,268,44,48);
  if(rectangle&&!visible[column])extra++;
 }
 label(context,'Cyan: sprite visible · gray: wall · pink: sprite drawn over nearer wall',20,350,colors.muted);
 element('sprite-depth-label').textContent=depth.toFixed(1);
 element('occlusion-values').textContent=`Sprite depth ${depth.toFixed(1)} · ${visible.filter(Boolean).length} visible columns · ${extra} extra columns inside the single rectangle.`;
}
bindRange('sprite-depth',drawOcclusion);
