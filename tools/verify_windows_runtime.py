#!/usr/bin/env python3
"""Run the actual Windows export with isolated Wine/Xvfb; never Windows-native acceptance."""
from pathlib import Path
import argparse,ctypes,hashlib,json,os,shutil,subprocess,tempfile,time
from PIL import ImageGrab

PROJECT=Path(__file__).resolve().parents[1]
RUNTIME=PROJECT/'.tools/windows/runtime'
WINE=RUNTIME/'bin/wine-portable'
X11=ctypes.CDLL('libX11.so.6')
XTST=ctypes.CDLL('libXtst.so.6')
X11.XOpenDisplay.argtypes=[ctypes.c_char_p];X11.XOpenDisplay.restype=ctypes.c_void_p
X11.XDefaultRootWindow.argtypes=[ctypes.c_void_p];X11.XDefaultRootWindow.restype=ctypes.c_ulong
X11.XQueryTree.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.POINTER(ctypes.c_ulong),ctypes.POINTER(ctypes.c_ulong),ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong)),ctypes.POINTER(ctypes.c_uint)]
X11.XFetchName.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.POINTER(ctypes.c_char_p)]
X11.XFree.argtypes=[ctypes.c_void_p]
X11.XRaiseWindow.argtypes=[ctypes.c_void_p,ctypes.c_ulong]
X11.XSetInputFocus.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.c_int,ctypes.c_ulong]
X11.XKeysymToKeycode.argtypes=[ctypes.c_void_p,ctypes.c_ulong];X11.XKeysymToKeycode.restype=ctypes.c_ubyte
X11.XFlush.argtypes=[ctypes.c_void_p]
X11.XCloseDisplay.argtypes=[ctypes.c_void_p]
X11.XInternAtom.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_int];X11.XInternAtom.restype=ctypes.c_ulong
X11.XGetWindowProperty.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.c_ulong,ctypes.c_long,ctypes.c_long,ctypes.c_int,ctypes.c_ulong,ctypes.POINTER(ctypes.c_ulong),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_ulong),ctypes.POINTER(ctypes.c_ulong),ctypes.POINTER(ctypes.POINTER(ctypes.c_ubyte))]
X11.XSendEvent.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.c_int,ctypes.c_long,ctypes.c_void_p]
X11.XGetWindowAttributes.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.c_void_p]
X11.XTranslateCoordinates.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.c_ulong,ctypes.c_int,ctypes.c_int,ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_ulong)]
XTST.XTestFakeKeyEvent.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_int,ctypes.c_ulong]
XTST.XTestFakeMotionEvent.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_ulong]
XTST.XTestFakeButtonEvent.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_int,ctypes.c_ulong]
# Wine creates/destroys helper windows during enumeration; a stale XID must not abort Python.
XErrorHandler=ctypes.CFUNCTYPE(ctypes.c_int,ctypes.c_void_p,ctypes.c_void_p)
_x_error_handler=XErrorHandler(lambda display,error:0)
X11.XSetErrorHandler.argtypes=[XErrorHandler];X11.XSetErrorHandler(_x_error_handler)


class Attributes(ctypes.Structure):
    _fields_=[('x',ctypes.c_int),('y',ctypes.c_int),('width',ctypes.c_int),('height',ctypes.c_int),('border_width',ctypes.c_int),('depth',ctypes.c_int),('visual',ctypes.c_void_p),('root',ctypes.c_ulong),('class_',ctypes.c_int),('bit_gravity',ctypes.c_int),('win_gravity',ctypes.c_int),('backing_store',ctypes.c_int),('backing_planes',ctypes.c_ulong),('backing_pixel',ctypes.c_ulong),('save_under',ctypes.c_int),('colormap',ctypes.c_ulong),('map_installed',ctypes.c_int),('map_state',ctypes.c_int),('all_event_masks',ctypes.c_long),('your_event_mask',ctypes.c_long),('do_not_propagate_mask',ctypes.c_long),('override_redirect',ctypes.c_int),('screen',ctypes.c_void_p)]
class ClientData(ctypes.Union):
    _fields_=[('b',ctypes.c_char*20),('s',ctypes.c_short*10),('l',ctypes.c_long*5)]
class ClientEvent(ctypes.Structure):
    _fields_=[('type',ctypes.c_int),('serial',ctypes.c_ulong),('send_event',ctypes.c_int),('display',ctypes.c_void_p),('window',ctypes.c_ulong),('message_type',ctypes.c_ulong),('format',ctypes.c_int),('data',ClientData)]
class Event(ctypes.Union):
    _fields_=[('xclient',ClientEvent),('pad',ctypes.c_long*24)]

def title(display,window):
    atom=X11.XInternAtom(display,b'_NET_WM_NAME',0)
    data=ctypes.POINTER(ctypes.c_ubyte)();actual_type=ctypes.c_ulong();format_=ctypes.c_int();count=ctypes.c_ulong();left=ctypes.c_ulong()
    if X11.XGetWindowProperty(display,window,atom,0,4096,0,0,ctypes.byref(actual_type),ctypes.byref(format_),ctypes.byref(count),ctypes.byref(left),ctypes.byref(data))==0 and data:
        value=ctypes.string_at(data,count.value).decode('utf-8','replace');X11.XFree(data)
        if value:return value
    old=ctypes.c_char_p()
    if not X11.XFetchName(display,window,ctypes.byref(old)) or not old.value:return ''
    result=old.value.decode('utf-8','replace');X11.XFree(old);return result

def geometry(display,window):
    result=Attributes()
    return result if X11.XGetWindowAttributes(display,window,ctypes.byref(result)) else None

def close_window(display,window):
    event=Event();event.xclient.type=33;event.xclient.send_event=1;event.xclient.display=display;event.xclient.window=window
    event.xclient.message_type=X11.XInternAtom(display,b'WM_PROTOCOLS',0);event.xclient.format=32
    event.xclient.data.l[0]=X11.XInternAtom(display,b'WM_DELETE_WINDOW',0);event.xclient.data.l[1]=0
    X11.XSendEvent(display,window,0,0,ctypes.byref(event));X11.XFlush(display)

def tree(display,root):
    result=[];pending=[root]
    while pending:
        current=pending.pop();result.append((current,title(display,current)))
        rr=ctypes.c_ulong();parent=ctypes.c_ulong();children=ctypes.POINTER(ctypes.c_ulong)();count=ctypes.c_uint()
        if X11.XQueryTree(display,current,ctypes.byref(rr),ctypes.byref(parent),ctypes.byref(children),ctypes.byref(count)):
            pending.extend(children[i] for i in range(count.value))
            if children:X11.XFree(children)
    return result

def find_game(display,root,process):
    until=time.monotonic()+35;previous=None;stable_since=0
    while time.monotonic()<until:
        windows=tree(display,root);candidates=[];detail=[]
        for window,name in windows:
            attrs=geometry(display,window)
            if not attrs:continue
            detail.append((hex(window),name,attrs.width,attrs.height,attrs.map_state))
            if window==root or attrs.map_state!=2 or attrs.width<800 or attrs.height<500:continue
            score=abs(attrs.width-1280)+abs(attrs.height-720)+(1500 if not name else 0)
            if 'desktop' in name.lower():score+=3000
            if '像素世界' in name or 'Pixel World' in name:score-=5000
            candidates.append((score,window,name))
        with (PROJECT/'builds/windows080-x11-tree.log').open('a') as output:output.write(repr(detail)+'\n')
        if candidates:
            candidates.sort(key=lambda value:(value[0],-value[1]));winner=candidates[0]
            if previous!=winner[1]:previous=winner[1];stable_since=time.monotonic()
            elif time.monotonic()-stable_since>=1.2:return winner[1],winner[2]
        if process.poll() is not None:raise RuntimeError('Windows game exited before its main window appeared; titles='+repr(windows))
        time.sleep(.2)
    raise RuntimeError('No stable game window; X11 titles: '+repr(windows))

def focus(display,window):
    X11.XRaiseWindow(display,window);X11.XSetInputFocus(display,window,2,0);X11.XFlush(display);time.sleep(.35)

def key(display,symbol):
    code=X11.XKeysymToKeycode(display,symbol)
    if not code:raise RuntimeError('No X11 keycode for '+hex(symbol))
    XTST.XTestFakeKeyEvent(display,code,1,0);X11.XFlush(display);time.sleep(.06)
    XTST.XTestFakeKeyEvent(display,code,0,0);X11.XFlush(display);time.sleep(.35)

def click(display,root,window,local_x,local_y):
    x=ctypes.c_int();y=ctypes.c_int();child=ctypes.c_ulong()
    X11.XTranslateCoordinates(display,window,root,0,0,ctypes.byref(x),ctypes.byref(y),ctypes.byref(child))
    XTST.XTestFakeMotionEvent(display,-1,x.value+local_x,y.value+local_y,0);X11.XFlush(display);time.sleep(.15)
    XTST.XTestFakeButtonEvent(display,1,1,0);X11.XFlush(display);time.sleep(.08)
    XTST.XTestFakeButtonEvent(display,1,0,0);X11.XFlush(display);time.sleep(.4)

def capture(display_name,display,root,window,target):
    data=ctypes.create_string_buffer(1024)
    if not X11.XGetWindowAttributes(display,window,data):raise RuntimeError('Cannot query game window geometry')
    attrs=ctypes.cast(data,ctypes.POINTER(ctypes.c_int))
    width,height=attrs[2],attrs[3]
    x=ctypes.c_int();y=ctypes.c_int();child=ctypes.c_ulong()
    X11.XTranslateCoordinates(display,window,root,0,0,ctypes.byref(x),ctypes.byref(y),ctypes.byref(child))
    picture=ImageGrab.grab(xdisplay=display_name).crop((x.value,y.value,x.value+width,y.value+height))
    picture.save(target)
    return {'path':str(target.relative_to(PROJECT)),'width':width,'height':height,'x':x.value,'y':y.value,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}

def locate_save(prefix):
    for path in prefix.rglob('farm_save.json'):
        resolved=path.resolve()
        if prefix.resolve() not in resolved.parents:raise RuntimeError('Save path escaped the isolated prefix')
        try:return path,json.loads(path.read_text())
        except (OSError,ValueError):pass
    return None,None

def clean_output(text):
    for marker in ['SCRIPT ERROR:', 'ERROR:', 'instances leaked']:
        if marker in text:raise RuntimeError('Game output contains '+marker)

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--exe',required=True,type=Path)
parser.add_argument('--pck',type=Path)
args=parser.parse_args();exe=args.exe.resolve();pck=(args.pck.resolve() if args.pck else exe.with_suffix('.pck'))
if not exe.exists():raise SystemExit('EXE does not exist: '+str(exe))
if not pck.exists():raise SystemExit('Adjacent PCK does not exist: '+str(pck))
out=PROJECT/'builds';out.mkdir(exist_ok=True)
report={'exe':str(exe),'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'pck':str(pck),'pck_sha256':hashlib.sha256(pck.read_bytes()).hexdigest(),'wine_version':subprocess.check_output([str(WINE),'--version'],text=True).strip(),'windows_native_tested':False,'wine_tested':True,'headless':False,'window':False,'save_restart':False,'captures':[]}
server=None;display_handle=None;env=None
try:
    number=next(i for i in range(121,150) if not Path('/tmp/.X11-unix/X'+str(i)).exists() and not Path('/tmp/.X'+str(i)+'-lock').exists())
    display_name=':'+str(number)
    server=subprocess.Popen([str(PROJECT/'.tools/display/usr/bin/Xvfb'),display_name,'-screen','0','1600x1000x24','-nolisten','tcp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    time.sleep(.4)
    if server.poll() is not None:raise RuntimeError('Xvfb startup failed')
    with tempfile.TemporaryDirectory(prefix='pixelworld-wine-test-') as directory:
        base=Path(directory);prefix=base/'prefix'
        run_dir=base/'像素世界 Windows 独立运行';run_dir.mkdir()
        runnable=run_dir/'PixelWorld.exe';shutil.copyfile(exe,runnable)
        assert hashlib.sha256(runnable.read_bytes()).hexdigest()==report['exe_sha256']
        run_pck=runnable.with_suffix('.pck');shutil.copyfile(pck,run_pck)
        assert hashlib.sha256(run_pck.read_bytes()).hexdigest()==report['pck_sha256']
        shutil.copytree(RUNTIME/'prefix-init',prefix,symlinks=True)
        env=dict(os.environ,DISPLAY=display_name,LIBGL_ALWAYS_SOFTWARE='1',WINEPREFIX=str(prefix),WINEARCH='win64',WINEDEBUG='-all',WINEDLLOVERRIDES='winemenubuilder.exe=d;mscoree=d;mshtml=d',XDG_DATA_HOME=str(base/'xdg'))
        init=subprocess.run([str(WINE),'wineboot.exe','--update'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=80)
        (out/'windows080-wine-init.log').write_text(init.stdout)
        if init.returncode:raise RuntimeError('Isolated Wine prefix update failed: '+init.stdout[-2000:])
        command=[str(WINE),str(runnable),'--headless','--audio-driver','Dummy','--fixed-fps','60','--quit-after','180']
        result=subprocess.run(command,cwd=run_dir,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=90)
        (out/'windows080-wine-headless.log').write_text(result.stdout)
        print('HEADLESS',result.returncode,result.stdout[-1800:],flush=True)
        if result.returncode:raise RuntimeError('Actual EXE headless startup failed')
        clean_output(result.stdout);report['headless']=True
        display_handle=X11.XOpenDisplay(display_name.encode())
        if not display_handle:raise RuntimeError('Cannot connect to own Xvfb')
        root=X11.XDefaultRootWindow(display_handle)
        gui_log=out/'windows080-wine-window.log'
        with gui_log.open('w') as stream:
            process=subprocess.Popen([str(WINE),str(runnable),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--max-fps','60','--quit-after','1800'],cwd=run_dir,env=env,stdout=stream,stderr=subprocess.STDOUT,text=True)
            try:
                window,name=find_game(display_handle,root,process);report['window_title']=name
                focus(display_handle,window);time.sleep(1.0)
                report['captures'].append(capture(display_name,display_handle,root,window,out/'windows080-wine-character-select.png'))
                click(display_handle,root,window,640,90);focus(display_handle,window)
                key(display_handle,0xff53);key(display_handle,0xff0d);time.sleep(1.0);key(display_handle,0xffc2)
                report['input_method']='keyboard_after_mouse_activation'
                until=time.monotonic()+3;save=None
                while time.monotonic()<until:
                    save_path,save=locate_save(prefix)
                    if save and save.get('appearance',{}).get('player_gender')=='female':break
                    time.sleep(.2)
                if not save or save.get('appearance',{}).get('player_gender')!='female':
                    report['input_method']='native_mouse'
                    click(display_handle,root,window,900,300);click(display_handle,root,window,1040,656);key(display_handle,0xffc2)
                    time.sleep(.8);save_path,save=locate_save(prefix)
                if not save or save.get('appearance',{}).get('player_gender')!='female':raise RuntimeError('Native keyboard/mouse did not create the expected female save')
                report['save_version']=save.get('version');report['appearance']=save.get('appearance');report['territory_saved']='territory' in save
                (out/'windows080-wine-save.json').write_text(json.dumps(save,ensure_ascii=False,indent=2)+'\n')
                report['captures'].append(capture(display_name,display_handle,root,window,out/'windows080-wine-farm.png'))
                key(display_handle,0x6d);time.sleep(.7)
                report['captures'].append(capture(display_name,display_handle,root,window,out/'windows080-wine-map.png'))
                report['window']=True
                close_window(display_handle,window)
                process.wait(timeout=20)
                if process.returncode:raise RuntimeError('Game window exited with '+str(process.returncode))
            finally:
                if process.poll() is None:process.terminate();process.wait(timeout=10)
        clean_output(gui_log.read_text())
        original_appearance=save['appearance'].copy()
        restart=subprocess.run(command,cwd=run_dir,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=90)
        (out/'windows080-wine-restart.log').write_text(restart.stdout)
        clean_output(restart.stdout)
        if restart.returncode:raise RuntimeError('Actual EXE restart failed')
        restored_path,restored=locate_save(prefix)
        if not restored or restored.get('appearance')!=original_appearance or restored.get('version')!=28 or 'farm_layout' not in restored:raise RuntimeError('Restart changed the saved avatar/schema')
        report['save_restart']=True;report['player_profile_isolated']=True;report['standalone_without_source']=True;report['unicode_path_tested']=True
        report['status']='passed'
        subprocess.run([str(RUNTIME/'root/usr/lib/wine/wineserver64'),'-k'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
        print('ACTUAL WINDOWS EXE UNDER WINE: PASS (not Windows-native)',flush=True)
except Exception as exc:
    report['status']='failed';report['error']=str(exc)
    print('ACTUAL WINDOWS EXE UNDER WINE: FAIL',str(exc),flush=True)
    if env:
        subprocess.run([str(RUNTIME/'root/usr/lib/wine/wineserver64'),'-k'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
finally:
    if display_handle:X11.XCloseDisplay(display_handle)
    if server:server.terminate();server.wait(timeout=10)
    (out/'windows080-wine-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
if report.get('status')!='passed':raise SystemExit(1)
