//
//  ViewController.h
//  UXAPP
//
//  Created by 葛绍飞 on 16/3/31.
//  Copyright © 2016年 sfeig. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <JavaScriptCore/JavaScriptCore.h>

//首先创建一个实现了JSExport协议的协议
@protocol JSIProtocol <JSExport>
//开始调用二维码扫描程序
-(void)startScan;
@end

@interface ViewController : UIViewController<UIWebViewDelegate,JSIProtocol>


@end

