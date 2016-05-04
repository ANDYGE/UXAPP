//
//  ViewController.m
//  UXAPP
//
//  Created by 葛绍飞 on 16/3/31.
//  Copyright © 2016年 sfeig. All rights reserved.
//

#import "ViewController.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import <AVFoundation/AVFoundation.h>

static const char *kScanQRCodeQueueName = "ScanQRCodeQueue";

@interface ViewController ()<AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic) AVCaptureSession *captureSession;
@property (nonatomic) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic) BOOL lastResult;

- (BOOL)startReading;

@end

@implementation ViewController
//除去状态栏的可视区域
CGRect viewBounds;
//状态栏的高度
int marginTop;
//首页面加载等待图
UIImageView *imgView;
bool isFirstLoad = true;

//浏览器对象
UIWebView *webview;

//用于block的自身引用
__weak ViewController *weakSelf;

//JS上下文环境对象
JSContext *context;

///整个的扫描、手工输入的容器
UIView *scanView;

//扫描页面标题
UILabel *title;
//扫描框容器
UIView *scanBoxView ;

//输入框容器
UIView *inputBoxView = nil;
UITextField *txtSSID;
UITextField *txtPwd;

//加载进度显示
UIActivityIndicatorView *activityIndicator;

UIAlertController *alerter;

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    weakSelf = self;
    
    marginTop = [[UIApplication sharedApplication] statusBarFrame].size.height;
    CGRect bounds = self.view.bounds;
    //marginTop = 0; //如果隐藏状态栏的话，调整此处的高度为0即可满屏
    viewBounds = CGRectMake(0, marginTop, bounds.size.width, bounds.size.height-marginTop);
    webview = [[UIWebView alloc] initWithFrame:viewBounds];
    webview.delegate = self;
    
    //加载本地html文件
    //    NSURL *url = [[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html"];
    //    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSString *path = @"http://www.uxian365.net";
    //path = @"http://192.168.0.200";
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:path]];
    
    [self.view addSubview:webview];
    [webview loadRequest:request];
    
    imgView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"flash"]];
    imgView.frame = viewBounds;
    [self.view addSubview:imgView];
    
    alerter = [UIAlertController alertControllerWithTitle:@"提示" message:@"" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alerter addAction:okAction];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden
{
    return NO;//YES可以隐藏状态栏
}

- (void)downloadDescFileWithSSID:(NSString *)ssid password:(NSString *)pwd{
    if(ssid.length>0&&pwd.length>0){
        NSString *url=[NSString stringWithFormat:@"http://www.uxian365.cn/bz/wfwifi.aspx?ssid=%@&pwd=%@",ssid,pwd];
        
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
        [self backToMain];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

-(void)backToMain{
    [scanView removeFromSuperview];
    scanView = nil;
    inputBoxView = nil;
    webview.hidden = false;
}

-(void)backBtnClicked:(id)sender{
    [self backToMain];
}

-(void)switchBtnClicked:(id)sender{
    UIButton* btn = (UIButton*)sender;
    if([btn.currentTitle isEqualToString: @"录入连接"])
    {
        if(inputBoxView == nil){
            //手动录入框
            inputBoxView = [[UIView alloc]init];
            int boxWidth = viewBounds.size.width-40;
            inputBoxView.frame = CGRectMake(0, marginTop+45, viewBounds.size.width, viewBounds.size.height-marginTop-45);
            inputBoxView.backgroundColor = [UIColor blackColor];
            [scanView addSubview:inputBoxView];
            inputBoxView.hidden = true;
            
            UILabel *lblSSID = [[UILabel alloc] init];
            lblSSID.frame = CGRectMake(20,10, boxWidth, 20);
            lblSSID.textColor = [UIColor whiteColor];
            lblSSID.text=@"请输入路由器的名称：";
            [inputBoxView addSubview:lblSSID];
            
            txtSSID = [[UITextField alloc]init];
            txtSSID.frame = CGRectMake(20, 40, boxWidth, 40);
            [txtSSID setBackgroundColor:[UIColor whiteColor]];
            txtSSID.textColor = [UIColor blackColor];
            txtSSID.placeholder = @"请录入路由器的名称";
            txtSSID.text = @"UXIAN-";
            [inputBoxView addSubview:txtSSID];
            
            UILabel *lblPwd = [[UILabel alloc]init];
            lblPwd.text = @"请输入路由器的密码";
            lblPwd.textColor = [UIColor whiteColor];
            lblPwd.frame = CGRectMake(20, 100, boxWidth, 20);
            [inputBoxView addSubview:lblPwd];
            
            txtPwd = [[UITextField alloc]init];
            txtPwd.frame = CGRectMake(20, 130, boxWidth, 40);
            [txtPwd setBackgroundColor:[UIColor whiteColor]];
            txtPwd.textColor = [UIColor blackColor];
            txtPwd.placeholder = @"请录入路由器的连接密码";
            [inputBoxView addSubview:txtPwd];
            
            UIButton *inputBtn = [[UIButton alloc]init];
            inputBtn.frame = CGRectMake(20, 200, boxWidth, 40);
            inputBtn.backgroundColor = [UIColor whiteColor];
            [inputBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            [inputBtn setTitle:@"连接" forState:UIControlStateNormal];
            [inputBtn.layer setMasksToBounds:YES];
            [inputBtn.layer setCornerRadius:10.0]; //设置矩形四个圆角半径
            [inputBtn.layer setBorderWidth:1.0]; //边框宽度
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGColorRef colorref = CGColorCreate(colorSpace,(CGFloat[]){ 1, 1, 0, 1 });
            [inputBtn.layer setBorderColor:colorref];//边框颜色
            
            [inputBtn addTarget:self action:@selector(inputBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
            [inputBoxView addSubview:inputBtn];
        }
        scanView.backgroundColor = [UIColor blackColor];
        scanBoxView.hidden = true;
        inputBoxView.hidden = false;
        [btn setTitle:@"扫码连接" forState:UIControlStateNormal];
        title.text = @"手动录入";
        
        [self stopReading];
    }
    else
    {
        scanBoxView.hidden = false;
        inputBoxView.hidden = true;
        [btn setTitle:@"录入连接" forState:UIControlStateNormal];
        title.text = @"扫码连接";
        
        [self startReading];
    }
}

-(void)inputBtnClicked:(id)sender{
    NSString *ssid = txtSSID.text;
    NSString *pwd = txtPwd.text;
    
    if(ssid.length>0&&pwd.length>0){
        [self downloadDescFileWithSSID:ssid password:pwd];
    }
    else{
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"提示信息" message:@"SSID和密码不能为空。" preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

//void (^prepareQRUI)()=^(){
-(void) startScan{
    NSLog(@"build the Scan View");
    webview.hidden = true;
    //[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:NO];
    //[self prefersStatusBarHidden];
    scanView = [[UIView alloc] init];
    scanView.frame = viewBounds;
    scanView.bounds = viewBounds;
    scanView.layer.frame = viewBounds;
    //[scanView setBackgroundColor:[UIColor blackColor]];
    [weakSelf.view addSubview:scanView];
    
    //导航条
    UIImageView *navImgView = [[UIImageView alloc] init];
    navImgView.frame = CGRectMake(0, marginTop, viewBounds.size.width, 45);
    UIImage *navImgBg =[[UIImage imageNamed:@"navBg.png"]stretchableImageWithLeftCapWidth:2 topCapHeight:3];
    [navImgView setImage:navImgBg];
    [scanView addSubview:navImgView];
    
    //返回按钮
    UIButton *backBtn = [[UIButton alloc] init];
    backBtn.frame = CGRectMake(5, marginTop+4, 80, 37);
    [backBtn setTitle:@"返回" forState:UIControlStateNormal];
    backBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    backBtn.contentEdgeInsets = UIEdgeInsetsMake(0,10,0,0);
    //返回按钮的背景图片
    UIImage *imgBack = [[UIImage imageNamed:@"backBtn.png"]stretchableImageWithLeftCapWidth:14 topCapHeight:2];
    [backBtn setBackgroundImage:imgBack forState:UIControlStateNormal];
    [backBtn addTarget:weakSelf action:@selector(backBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [scanView addSubview:backBtn];
    
    //连接方式切换按钮
    UIButton *switchBtn = [[UIButton alloc]init];
    switchBtn.frame = CGRectMake(viewBounds.size.width-100, marginTop+4, 95, 37);
    UIImage *imgSwitch = [[UIImage imageNamed:@"switchBtn.png"]stretchableImageWithLeftCapWidth:14 topCapHeight:2];
    [switchBtn setBackgroundImage:imgSwitch forState:UIControlStateNormal];
    [switchBtn setTitle:@"录入连接" forState:UIControlStateNormal];
    switchBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [switchBtn addTarget:weakSelf action:@selector(switchBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [scanView addSubview:switchBtn];
    
    //标题Label
    title = [[UILabel alloc]init];
    title.textAlignment = NSTextAlignmentCenter;
    title.frame = CGRectMake(viewBounds.size.width/2-60, marginTop+4, 120, 37);
    title.text = @"扫码连接";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont fontWithName:@"Arial" size:20.0f];
    [scanView addSubview:title];
    
    
    //扫描区
    scanBoxView = [[UIView alloc]init];
    scanBoxView.frame = CGRectMake(viewBounds.size.width/2-140, viewBounds.size.height/2-160, 280, 320);
    [scanView addSubview:scanBoxView];
    
    //扫描框背景图片
    UIImageView *imgBox = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pick_bg.png"]];
    //设置位置到界面的中间
    imgBox.frame = CGRectMake(0,10, 280, 280);
    //添加到视图上
    [scanBoxView addSubview:imgBox];
    
    //模拟扫描线
    UIImageView *imgLine = [[UIImageView alloc] initWithFrame:CGRectMake(5, 15, 270, 2)];
    imgLine.image = [UIImage imageNamed:@"line.png"];
    [imgBox addSubview:imgLine];
    
    [UIView animateWithDuration:2.8 delay:0 options:UIViewAnimationOptionRepeat|UIViewAnimationOptionAutoreverse animations:^{
        imgLine.frame = CGRectMake(5, 260, 270, 2);
    } completion:nil];
    
    //扫描提示文字
    UILabel *infoLabel = [[UILabel alloc]init];
    infoLabel.frame = CGRectMake(0, 300, 280, 20);
    infoLabel.textAlignment = NSTextAlignmentCenter;
    infoLabel.numberOfLines = 0;
    infoLabel.text = @"将二维码放入框内，即可自动扫描";
    infoLabel.font = [UIFont fontWithName:@"Arial" size:16.0f];
    infoLabel.textColor = [UIColor whiteColor];
    [scanBoxView addSubview:infoLabel];
    
    [weakSelf startReading];
};

-(void)showLoading{
    //显示加载进度
    //    UIView *view = [[UIView alloc] initWithFrame:viewBounds];
    //    [view setTag:108];
    //    [view setBackgroundColor:[UIColor blackColor]];
    //    [view setAlpha:0.5];
    //    [self.view addSubview:view];
    if(isFirstLoad)
    {
        activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        [activityIndicator setCenter:self.view.center];
        [activityIndicator setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhite];
        [self.view addSubview:activityIndicator];
        [activityIndicator setBackgroundColor:[UIColor blackColor]];
        [activityIndicator setAlpha:0.5];
        activityIndicator.layer.cornerRadius = 3;
        activityIndicator.layer.masksToBounds = true;
    }
    [activityIndicator startAnimating];
}

-(void)hideLoading{
    [activityIndicator stopAnimating];
    //    UIView *view = (UIView*)[self.view viewWithTag:108];
    //    [view removeFromSuperview];
    if (isFirstLoad) {
        isFirstLoad=false;
        [imgView removeFromSuperview];
    }
}

- (BOOL)startReading
{
    _lastResult = YES;
    // 获取 AVCaptureDevice 实例
    NSError * error;
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    // 初始化输入流
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (!input) {
        NSLog(@"%@", [error localizedDescription]);
        return NO;
    }
    // 创建会话
    _captureSession = [[AVCaptureSession alloc] init];
    // 添加输入流
    [_captureSession addInput:input];
    // 初始化输出流
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    //    int width = self.view.bounds.size.width;
    //    [captureMetadataOutput setRectOfInterest:CGRectMake((124)/width ,((width -220)/2)/width ,220/width ,220/width )];
    // 添加输出流
    [_captureSession addOutput:captureMetadataOutput];
    
    // 创建dispatch queue.
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create(kScanQRCodeQueueName, NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    // 设置元数据类型 AVMetadataObjectTypeQRCode
    [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    
    // 创建输出对象
    _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    //[_videoPreviewLayer setFrame:self.view.layer.bounds];
    _videoPreviewLayer.frame = scanView.layer.bounds;
    //[_sanFrameView.layer addSublayer:_videoPreviewLayer];
    [scanView.layer insertSublayer:_videoPreviewLayer atIndex:0];
    // 开始会话
    [_captureSession startRunning];
    
    return YES;
}

- (void)stopReading
{
    // 停止会话
    [_captureSession stopRunning];
    [_videoPreviewLayer removeFromSuperlayer];
    _captureSession = nil;
}

- (void)reportScanResult:(NSString *)result
{
    [self stopReading];
    if (!_lastResult) {
        return;
    }
    _lastResult = NO;
    
    NSString *pat = @"SSID=[0-9a-zA-Z\\-]+&PWD=[0-9]+";
    NSRegularExpression *reg = [[NSRegularExpression alloc]initWithPattern:pat
                                                                   options:NSRegularExpressionCaseInsensitive
                                                                     error:nil];
    
    NSArray *results = [reg matchesInString:result options:0 range:NSMakeRange(0, result.length)];
    //NSLog(@"%d",results.count);
    if(results.count > 0)
    {
        NSTextCheckingResult *r = results[0];
        NSString *dataStr = [NSString stringWithFormat:@"%@",[result substringWithRange:r.range]];
        NSRange range = [dataStr rangeOfString:@"&PWD=" options:NSCaseInsensitiveSearch];
        NSRange ssidRange = {5,range.location-5};
        NSString *ssid =[dataStr substringWithRange:ssidRange];
        NSString *pwd =[dataStr substringFromIndex:range.location+range.length];
        [self downloadDescFileWithSSID:ssid password:pwd];
    }
    else{
        [self backToMain];
        NSString *mes = [NSString stringWithFormat:@"您扫描的不是有效的连接二维码\r\n 该二维码数据为：%@ ",result];
        [self alert:mes];
    }
    
    // 以及处理了结果，下次扫描
    _lastResult = YES;
}

-(void)alert:(NSString *)info{
    [alerter setMessage:info];
    [self presentViewController:alerter animated:YES completion:nil];
}


#pragma UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    return YES;
}

-(void)webView:(nonnull UIWebView *)webView didFailLoadWithError:(nullable NSError *)error{
    [self hideLoading];
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"提示信息" message:@"未能加载成功，请确认你是否可以链接互联网。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)webViewDidStartLoad:(nonnull UIWebView *)webView{
    //NSLog(@"开始加载");
    [self showLoading];
}

-(void)webViewDidFinishLoad:(nonnull UIWebView *)webView{
    //NSLog(@"开始结束");
    [self hideLoading];
    
    //    对于调用js的时候最好这个方法里面或者之后
    JSContext *context=[webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    [context evaluateScript:@"window.localStorage.isIOSApp=true;"];
    context[@"JSI4IOS"] = weakSelf;
}

#pragma AVCaptureMetadataOutputObjectsDelegate

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects
      fromConnection:(AVCaptureConnection *)connection
{
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
        NSString *result;
        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
            result = metadataObj.stringValue;
        } else {
            NSLog(@"不是二维码");
        }
        [self performSelectorOnMainThread:@selector(reportScanResult:) withObject:result waitUntilDone:NO];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
