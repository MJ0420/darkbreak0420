#import "Controller.h"
#import "GPSIPC.h"
#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <math.h>

@interface GPSPassThroughWindow : UIWindow
@end
@implementation GPSPassThroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:point withEvent:event];
    if (v == self || v == self.rootViewController.view) return nil;
    return v;
}
@end

@class GPSOverlayController;
@interface GPSPad : UIView
@property(nonatomic,copy) void (^change)(double east, double north);
@end
@implementation GPSPad {
    UIView *_thumb;
    UIPanGestureRecognizer *_pan;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.layer.cornerRadius = frame.size.width / 2;
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.65];
        self.layer.borderWidth = 2;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:.65].CGColor;
        _thumb = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 49, 49)];
        _thumb.layer.cornerRadius = 24.5;
        _thumb.backgroundColor = [UIColor colorWithRed:.23 green:.72 blue:1 alpha:.90];
        _thumb.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        _thumb.userInteractionEnabled = NO;
        [self addSubview:_thumb];
        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(move:)];
        [self addGestureRecognizer:_pan];
    }
    return self;
}
- (void)move:(UIPanGestureRecognizer *)pan {
    CGPoint mid = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled || pan.state == UIGestureRecognizerStateFailed) {
        _thumb.center = mid;
        if (self.change) self.change(0,0);
        return;
    }
    CGPoint p = [pan locationInView:self];
    double x = (p.x-mid.x)/((self.bounds.size.width-49)/2.0);
    double y = (mid.y-p.y)/((self.bounds.size.height-49)/2.0);
    double length = hypot(x,y);
    if (length > 1) {x /= length; y /= length;}
    _thumb.center = CGPointMake(mid.x+x*(self.bounds.size.width-49)/2.0, mid.y-y*(self.bounds.size.height-49)/2.0);
    if (self.change) self.change(x,y);
}
@end

@interface GPSRootViewController : UIViewController
@end
@implementation GPSRootViewController
- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    view.backgroundColor = [UIColor clearColor];
    self.view = view;
}
@end

@interface GPSOverlayController () <MKLocalSearchCompleterDelegate, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, MKMapViewDelegate, UISearchBarDelegate>
@end
@implementation GPSOverlayController {
    GPSModel _state;
    GPSPassThroughWindow *_window;
    GPSRootViewController *_root;
    UIButton *_bubble;
    UIView *_panel;
    UIScrollView *_scroll;
    MKMapView *_map;
    MKPointAnnotation *_draftPin;
    UISearchBar *_search;
    UITableView *_resultsTable;
    MKLocalSearchCompleter *_completer;
    NSArray<MKLocalSearchCompletion *> *_results;
    UITextField *_latField, *_lngField, *_speedField, *_favoriteField;
    UILabel *_status, *_speedStatus;
    UISlider *_slider;
    GPSPad *_pad;
    UIButton *_padToggle;
    NSTimer *_movementTimer;
    NSTimeInterval _lastTick;
    BOOL _didStart;
    BOOL _hasDraft;
    double _draftLat, _draftLng;
}
+ (instancetype)shared {
    static GPSOverlayController *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [GPSOverlayController new]; });
    return instance;
}
static UIButton *MJButton(NSString *title, UIColor *color, id target, SEL action, CGRect frame) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = frame;
    b.backgroundColor = color;
    b.layer.cornerRadius = 11;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}
static UITextField *MJField(NSString *placeholder, CGRect frame) {
    UITextField *t = [[UITextField alloc] initWithFrame:frame];
    t.placeholder = placeholder;
    t.font = [UIFont systemFontOfSize:14];
    t.textColor = UIColor.whiteColor;
    t.backgroundColor = [UIColor colorWithWhite:.16 alpha:1];
    t.layer.cornerRadius = 8;
    t.keyboardType = UIKeyboardTypeNumbersAndPunctuation; // supports negative coordinates
    t.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,10,1)];
    t.leftViewMode = UITextFieldViewModeAlways;
    return t;
}
static UILabel *MJLabel(NSString *txt, CGRect frame, CGFloat size) {
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.text = txt;
    l.font = [UIFont systemFontOfSize:size];
    l.textColor = UIColor.whiteColor;
    l.numberOfLines = 0;
    return l;
}
- (void)start {
    if (_didStart) return;
    _didStart = YES;
    gps_model_init(&_state);
    GPSModel zero; gps_model_init(&zero); MJGPSWrite(&zero);
    _window = [[GPSPassThroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    _window.backgroundColor = UIColor.clearColor;
    _window.windowLevel = UIWindowLevelAlert+120;
    _root = [GPSRootViewController new];
    _window.rootViewController = _root;
    _window.hidden = NO;

    CGRect bounds = UIScreen.mainScreen.bounds;
    _bubble = MJButton(@"⚙", [UIColor colorWithRed:.1 green:.35 blue:.57 alpha:.93], self, @selector(togglePanel), CGRectMake(bounds.size.width-54, bounds.size.height*.43, 47,47));
    _bubble.titleLabel.font = [UIFont systemFontOfSize:25];
    [_root.view addSubview:_bubble];
    UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragBubble:)];
    [_bubble addGestureRecognizer:drag];
    [self createPanel];
    _lastTick = [NSDate timeIntervalSinceReferenceDate];
    // Common modes keep motion ticking while the joystick pan gesture is tracked.
    _movementTimer = [NSTimer timerWithTimeInterval:0.15 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_movementTimer forMode:NSRunLoopCommonModes];
}
- (void)dragBubble:(UIPanGestureRecognizer *)drag {
    CGPoint pos = [drag translationInView:_root.view];
    if (drag.state == UIGestureRecognizerStateBegan || drag.state == UIGestureRecognizerStateChanged) {
        CGPoint c = _bubble.center;
        c.x = fmin(fmax(c.x+pos.x,26),_root.view.bounds.size.width-26);
        c.y = fmin(fmax(c.y+pos.y,55),_root.view.bounds.size.height-45);
        _bubble.center = c;
        [drag setTranslation:CGPointZero inView:_root.view];
    }
}
- (void)createPanel {
    CGFloat w = UIScreen.mainScreen.bounds.size.width;
    CGFloat h = UIScreen.mainScreen.bounds.size.height;
    _panel = [[UIView alloc] initWithFrame:CGRectMake(10, 40, w-20, h-80)];
    _panel.backgroundColor = [UIColor colorWithRed:.075 green:.09 blue:.13 alpha:.985];
    _panel.layer.cornerRadius = 18;
    _panel.clipsToBounds = YES;
    _panel.hidden = YES;
    [_root.view addSubview:_panel];
    CGFloat pw = _panel.bounds.size.width;
    _scroll = [[UIScrollView alloc] initWithFrame:_panel.bounds];
    _scroll.contentSize = CGSizeMake(pw, 805);
    _scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_panel addSubview:_scroll];
    UILabel *header = MJLabel(@"GPS Joystick  ·  地图搜索", CGRectMake(15,9,pw-85,28),18);
    header.font = [UIFont boldSystemFontOfSize:18];
    [_scroll addSubview:header];
    [_scroll addSubview:MJButton(@"关闭",UIColor.darkGrayColor,self,@selector(togglePanel),CGRectMake(pw-72,9,62,29))];
    _search = [[UISearchBar alloc] initWithFrame:CGRectMake(8,46,pw-16,44)];
    _search.placeholder = @"搜索 KLCC、建筑物、街道或地址";
    _search.searchBarStyle = UISearchBarStyleMinimal;
    _search.delegate = self;
    [_scroll addSubview:_search];
    _map = [[MKMapView alloc] initWithFrame:CGRectMake(12,96,pw-24,220)];
    _map.layer.cornerRadius = 9;
    _map.delegate = self;
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2DMake(3.15659,101.71779),1400,1400);
    [_map setRegion:region animated:NO];
    [_scroll addSubview:_map];
    UITapGestureRecognizer *mapTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mapTap:)];
    [_map addGestureRecognizer:mapTap];

    _completer = [MKLocalSearchCompleter new];
    _completer.delegate = self;
    _completer.region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2DMake(3.14,101.7),180000,180000);
    _completer.resultTypes = MKLocalSearchCompleterResultTypeAddress | MKLocalSearchCompleterResultTypePointOfInterest;
    _results = @[];
    _resultsTable = [[UITableView alloc] initWithFrame:CGRectMake(12,91,pw-24,185) style:UITableViewStylePlain];
    _resultsTable.dataSource = self;
    _resultsTable.delegate = self;
    _resultsTable.hidden = YES;
    _resultsTable.layer.cornerRadius=9;
    [_scroll addSubview:_resultsTable];

    [_scroll addSubview:MJLabel(@"纬度 Latitude",CGRectMake(14,331,pw/2-16,21),13)];
    [_scroll addSubview:MJLabel(@"经度 Longitude",CGRectMake(pw/2+1,331,pw/2-16,21),13)];
    _latField = MJField(@"例如 3.156590",CGRectMake(12,356,pw/2-18,38));
    _lngField = MJField(@"例如 101.717790",CGRectMake(pw/2+1,356,pw/2-13,38));
    _latField.delegate = self; _lngField.delegate=self;
    _latField.text = @"3.156590"; _lngField.text = @"101.717790";
    _hasDraft = YES; _draftLat=3.156590; _draftLng=101.717790;
    [_scroll addSubview:_latField]; [_scroll addSubview:_lngField];
    [_scroll addSubview:MJButton(@"确认定位 / Teleport",[UIColor colorWithRed:.13 green:.42 blue:.79 alpha:1],self,@selector(confirmTeleport),CGRectMake(12,407,pw-24,44))];
    _speedStatus = MJLabel(@"速度 5 km/h",CGRectMake(14,461,pw-30,24),14);
    [_scroll addSubview:_speedStatus];
    _slider = [[UISlider alloc] initWithFrame:CGRectMake(18,490,pw-110,31)];
    _slider.minimumValue=5;_slider.maximumValue=50;_slider.value=5;
    [_slider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    [_scroll addSubview:_slider];
    _speedField = MJField(@"5–50",CGRectMake(pw-90,488,74,37));
    _speedField.text=@"5";
    [_scroll addSubview:_speedField];
    [_scroll addSubview:MJButton(@"应用速度",UIColor.darkGrayColor,self,@selector(applySpeed),CGRectMake(pw-100,530,88,33))];
    _status = MJLabel(@"当前真实定位 · 尚未开始模拟", CGRectMake(13,570,pw-26,47),14);
    [_scroll addSubview:_status];
    [_scroll addSubview:MJButton(@"暂停移动",UIColor.darkGrayColor,self,@selector(pause),CGRectMake(12,628,(pw-35)/2,40))];
    _padToggle = MJButton(@"显示/隐藏摇杆",UIColor.darkGrayColor,self,@selector(togglePad),CGRectMake((pw+1)/2,628,(pw-35)/2,40));
    [_scroll addSubview:_padToggle];
    [_scroll addSubview:MJButton(@"恢复真实 GPS",[UIColor colorWithRed:.68 green:.19 blue:.20 alpha:1],self,@selector(restore),CGRectMake(12,677,pw-24,43))];
    [_scroll addSubview:MJButton(@"收藏坐标",UIColor.darkGrayColor,self,@selector(saveFavorite),CGRectMake(12,729,(pw-35)/2,39))];
    [_scroll addSubview:MJButton(@"常用地点",UIColor.darkGrayColor,self,@selector(showFavorites),CGRectMake((pw+1)/2,729,(pw-35)/2,39))];

    _pad = [[GPSPad alloc] initWithFrame:CGRectMake(16,h-175,126,126)];
    __weak GPSOverlayController *weakSelf = self;
    _pad.change = ^(double east, double north) {
        GPSOverlayController *s = weakSelf;
        if (s) gps_model_set_joystick(&s->_state, east, north);
    };
    _pad.hidden = YES;
    [_root.view addSubview:_pad];
    // Joystick stays at bottom-left in v0.2. Floating settings button is draggable.
}
- (void)togglePanel {
    _panel.hidden = !_panel.hidden;
    if (!_panel.hidden) {[_root.view bringSubviewToFront:_panel]; _resultsTable.hidden=YES;}
}
- (void)togglePad { _pad.hidden = !_pad.hidden; }
- (void)tick:(NSTimer *)timer {
    (void)timer;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval dt = now - _lastTick;
    _lastTick = now;
    if (dt <= 0) return;
    if (!_state.active || (_state.axis_east == 0 && _state.axis_north == 0)) return;
    gps_model_step(&_state,dt);
    MJGPSWrite(&_state);
    [self updateStatus];
}
- (void)updateStatus {
    _status.text = _state.active ? [NSString stringWithFormat:@"当前生效：%.6f, %.6f\n速度：%.0f km/h",_state.latitude,_state.longitude,_state.speed_kmh] : @"当前真实定位 · 尚未开始模拟";
}
- (void)prepareDraft:(CLLocationCoordinate2D)coordinate {
    if (!CLLocationCoordinate2DIsValid(coordinate)) return;
    _hasDraft = YES;
    _draftLat = coordinate.latitude;
    _draftLng = coordinate.longitude;
    _latField.text = [NSString stringWithFormat:@"%.6f",_draftLat];
    _lngField.text = [NSString stringWithFormat:@"%.6f",_draftLng];
    if (_draftPin) [_map removeAnnotation:_draftPin];
    _draftPin = [MKPointAnnotation new];
    _draftPin.coordinate = coordinate;
    _draftPin.title = @"待确认的位置（尚未生效）";
    [_map addAnnotation:_draftPin];
    [_map setCenterCoordinate:coordinate animated:YES];
}
- (void)mapTap:(UITapGestureRecognizer *)tap {
    CGPoint p = [tap locationInView:_map];
    CLLocationCoordinate2D c = [_map convertPoint:p toCoordinateFromView:_map];
    [self prepareDraft:c];
    [_root.view endEditing:YES];
}
- (BOOL)parseDraft:(double *)lat longitude:(double *)lng {
    NSScanner *a = [NSScanner scannerWithString:_latField.text ?: @""];
    NSScanner *b = [NSScanner scannerWithString:_lngField.text ?: @""];
    double x,y;
    if (![a scanDouble:&x] || !a.isAtEnd || ![b scanDouble:&y] || !b.isAtEnd || !gps_valid_coordinate(x,y)) return NO;
    *lat=x;*lng=y;return YES;
}
- (void)alert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"GPS Joystick" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [_root presentViewController:alert animated:YES completion:nil];
}
- (void)confirmTeleport {
    double lat,lng;
    if (![self parseDraft:&lat longitude:&lng]) { [self alert:@"请输入有效经纬度（纬度 -90~90，经度 -180~180）。"]; return; }
    gps_model_teleport(&_state,lat,lng);
    if (!MJGPSWrite(&_state)) {[self alert:@"无法通知定位组件，定位未确认成功。请检查越狱插件是否已加载。"]; gps_model_restore(&_state); return;}
    [self prepareDraft:CLLocationCoordinate2DMake(lat,lng)];
    _pad.hidden = NO;
    [self updateStatus];
    _resultsTable.hidden=YES;
    [_root.view endEditing:YES];
}
- (void)pause {gps_model_pause(&_state); [self updateStatus];}
- (void)restore {
    gps_model_restore(&_state);
    if (!MJGPSWrite(&_state)) [self alert:@"发送恢复命令失败，请在安全模式下禁用插件或重启 SpringBoard。"];
    _pad.hidden=YES;
    [self updateStatus];
}
- (void)speedChanged:(UISlider *)slider {
    int speed = (int)lround(slider.value);
    gps_model_set_speed(&_state,speed);
    _speedField.text = [NSString stringWithFormat:@"%d",speed];
    _speedStatus.text = [NSString stringWithFormat:@"速度 %d km/h",speed];
}
- (void)applySpeed {
    NSInteger speed = _speedField.text.integerValue;
    if (speed < 5 || speed > 50) {[self alert:@"速度必须在 5 到 50 km/h 之间"];return;}
    gps_model_set_speed(&_state,speed);
    _slider.value=(float)speed;
    _speedStatus.text=[NSString stringWithFormat:@"速度 %ld km/h",(long)speed];
    [_root.view endEditing:YES];
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    _completer.queryFragment = searchText ?: @"";
    if (searchText.length==0) {_results=@[]; _resultsTable.hidden=YES;}
}
- (void)completerDidUpdateResults:(MKLocalSearchCompleter *)completer {
    _results = completer.results;
    [_resultsTable reloadData];
    _resultsTable.hidden = (_results.count == 0);
}
- (void)completer:(MKLocalSearchCompleter *)completer didFailWithError:(NSError *)error {
    (void)completer; (void)error;
    _resultsTable.hidden=YES;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView;(void)section; return _results.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"place"];
    if (!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"place"];
    MKLocalSearchCompletion *result=_results[indexPath.row];
    cell.textLabel.text=result.title;
    cell.detailTextLabel.text=result.subtitle;
    cell.textLabel.font=[UIFont systemFontOfSize:14];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (indexPath.row < 0 || (NSUInteger)indexPath.row >= _results.count) return;
    MKLocalSearchCompletion *completion=_results[indexPath.row];
    _search.text=completion.title;
    _resultsTable.hidden=YES;
    [_search resignFirstResponder];
    MKLocalSearchRequest *req=[[MKLocalSearchRequest alloc] initWithCompletion:completion];
    MKLocalSearch *search=[[MKLocalSearch alloc] initWithRequest:req];
    __weak GPSOverlayController *weakSelf=self;
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        GPSOverlayController *s=weakSelf;
        if (!s) return;
        MKMapItem *item=response.mapItems.firstObject;
        if (item && !error) [s prepareDraft:item.placemark.coordinate];
        else [s alert:@"没有取得该地点坐标，请尝试完整地址或直接在地图上选点。"]; 
    }];
}
- (void)saveFavorite {
    double lat,lng;
    if (![self parseDraft:&lat longitude:&lng]) {[self alert:@"请先在地图选点或填写有效经纬度"];return;}
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"保存常用位置" message:@"保存的是候选坐标，不会立即改变 GPS。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.placeholder=@"地点名称";}];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action;
        NSString *name=alert.textFields.firstObject.text;
        if (!name.length) name=@"未命名位置";
        NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
        NSMutableArray *favorites=[[defaults arrayForKey:@"com.mj.gpsjoy.favorites"] ?: @[] mutableCopy];
        [favorites addObject:@{@"name":name,@"lat":@(lat),@"lng":@(lng)}];
        [defaults setObject:favorites forKey:@"com.mj.gpsjoy.favorites"];
    }]];
    [_root presentViewController:alert animated:YES completion:nil];
}
- (void)showFavorites {
    NSArray *favorites=[NSUserDefaults.standardUserDefaults arrayForKey:@"com.mj.gpsjoy.favorites"] ?: @[];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"常用位置" message:@"选择只填写坐标，请再点击「确认定位」" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *place in favorites) {
        NSString *label=[NSString stringWithFormat:@"%@ (%.5f, %.5f)",place[@"name"], [place[@"lat"] doubleValue],[place[@"lng"] doubleValue]];
        [alert addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            (void)action; [self prepareDraft:CLLocationCoordinate2DMake([place[@"lat"] doubleValue],[place[@"lng"] doubleValue])];
        }]];
    }
    if (!favorites.count) alert.message=@"暂无收藏，先通过地图选择位置后点击收藏坐标。";
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *pop=alert.popoverPresentationController;
    if (pop) {pop.sourceView=_panel;pop.sourceRect=CGRectMake(_panel.bounds.size.width/2,_panel.bounds.size.height-35,1,1);}
    [_root presentViewController:alert animated:YES completion:nil];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {[textField resignFirstResponder];return YES;}
@end
