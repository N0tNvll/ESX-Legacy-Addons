const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');
const root = path.resolve(__dirname, '../../[esx_addons]/esx_garage/web/dist');
const output = process.argv[2];
const server = http.createServer((request,response) => {
  const url = new URL(request.url, 'http://localhost');
  const file = path.resolve(root, '.' + decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname));
  if (!file.startsWith(root + path.sep)) { response.writeHead(403); response.end(); return; }
  try {
    const types = { '.html':'text/html', '.js':'text/javascript', '.css':'text/css', '.webp':'image/webp', '.ttf':'font/ttf', '.json':'application/json' };
    response.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream'); response.end(fs.readFileSync(file));
  } catch { response.writeHead(404); response.end(); }
});
const pagination = {page:1,pageSize:30,hasNext:false,hasPrevious:false};
const car = (name, job) => ({id:job?'COP':'MINE',plate:job?'COP':'MINE',name,model:'adder',type:'car',stored:true,impounded:name.includes('Impound'),impoundFee:name.includes('Impound')?100:undefined,mileage:100,fuel:38,engine:75,body:80,isFavorite:false,job});
(async () => {
  await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
  const browser = await chromium.launch({channel:'msedge',headless:true});
  try {
    const page = await browser.newPage({viewport:{width:1920,height:1080}});
    const errors=[],requests=[];
    let limitFleetOnce=true;
    let delayFleet=false,releaseFleet;
    page.on('pageerror',error => errors.push(error.message));
    await page.addInitScript(() => { window.GetParentResourceName=()=>'esx_garage'; });
    await page.route('https://esx_garage/**',route => {
      const request=route.request(),data=request.postDataJSON();requests.push({url:request.url(),data});
      if(request.url().endsWith('/garage:getVehicles')&&data.fleetGarageId&&limitFleetOnce){limitFleetOnce=false;return route.fulfill({json:{success:false,error:'rate_limited'}});}
      const payload=request.url().endsWith('/garage:getVehicles')
        ? {vehicles:[car(data.fleetGarageId?'Fleet Impounded':'Personal Impounded',data.fleetGarageId?'police':undefined)],pagination}
        : true;
      if(delayFleet&&data.fleetGarageId){delayFleet=false;return new Promise(resolve=>{releaseFleet=()=>resolve(route.fulfill({json:{success:true,data:payload}}));});}
      return route.fulfill({json:{success:true,data:payload}});
    });
    await page.goto(`http://127.0.0.1:${server.address().port}`);
    const open=async(type,name,job) => {
      await page.evaluate(({type,name,job,pagination,vehicle}) => {
        window.postMessage({type:'closeGarage',payload:{}},'*');
        window.postMessage({type:'openGarage',payload:{garage:{id:type,name,type,label:name,keys:true,fleets:type==='impound'?[{id:'police',name:'Police Fleet'}]:undefined},vehicles:[vehicle],pagination}},'*');
      },{type,name,job,pagination,vehicle:car(name+' Car',job)});
      await page.getByText(name+' Car',{exact:true}).first().waitFor();
    };
    await page.waitForFunction(() => document.querySelector('#root')?.childElementCount > 0);
    await page.evaluate(() => window.postMessage({type:'setLocale',payload:'en'},'*'));
    await open('public','Personal');await page.getByText('Personal Car',{exact:true}).first().click();
    await page.getByRole('button',{name:'Transfer Vehicle',exact:true}).waitFor();
    await open('job','Police','police');await page.getByText('Police Car',{exact:true}).first().click();
    await page.getByRole('button',{name:'Rename Vehicle',exact:true}).last().waitFor();
    assert.equal(await page.getByRole('button',{name:'Transfer Vehicle',exact:true}).count(),0);
    assert.equal(await page.getByRole('button',{name:'Give Keys',exact:true}).count(),0);
    await open('impound','Impound');
    const selector=page.getByRole('combobox');
    await selector.waitFor({timeout:5000});
    assert.equal(await selector.getAttribute('aria-label'),'Vehicle ownership');
    await selector.selectOption('police');
    await page.getByText('Fleet Impounded',{exact:true}).first().waitFor();
    assert.equal(requests.filter(r=>r.url.endsWith('/garage:getVehicles')).at(-1).data.fleetGarageId,'police');
    assert.equal(requests.filter(r=>r.url.endsWith('/garage:getVehicles')&&r.data.fleetGarageId==='police').length,2);
    await page.getByText('Fleet Impounded',{exact:true}).first().click();
    await page.getByRole('button',{name:'Rename Vehicle',exact:true}).last().waitFor();
    assert.equal(await page.getByRole('button',{name:'Transfer Vehicle',exact:true}).count(),0);
    if(output){await page.waitForTimeout(500);await page.screenshot({path:path.join(output,'unified-job-impound.png')});}
    await selector.selectOption('');
    await page.getByText('Personal Impounded',{exact:true}).first().waitFor();
    await page.getByText('Fleet Impounded',{exact:true}).waitFor({state:'detached'});
    await page.getByText('Personal Impounded',{exact:true}).first().click();
    await page.getByRole('button',{name:'Transfer Vehicle',exact:true}).waitFor();
    delayFleet=true;
    const pendingFleet=page.waitForRequest(request=>request.url().endsWith('/garage:getVehicles')&&request.postDataJSON().fleetGarageId==='police');
    await selector.selectOption('police');await pendingFleet;
    await open('public','Personal');
    await releaseFleet();
    await open('impound','Reopened Impound');
    assert.equal(await page.getByRole('combobox').isEnabled(),true);
    assert.equal(await page.getByRole('combobox').inputValue(),'');
    assert.equal(await page.getByText('Fleet Impounded',{exact:true}).count(),0);
    assert.deepEqual(errors,[]);
    console.log('PASS built NUI: personal actions, job restrictions, impound scopes, cooldown retry and stale response/close handling.');
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;}).finally(()=>server.close());
