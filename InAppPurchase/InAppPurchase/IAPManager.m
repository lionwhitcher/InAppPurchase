//
//  IAPManager.m
//  NewTest
//
//  Created by mac on 2019/7/11.
//  Copyright © 2019 MyCompany. All rights reserved.
//

#import "IAPManager.h"

#define Last_Product_Order_Path @"in-app-purchase.plist"

static IAPManager* instance = nil;

@interface IAPManager ()<SKPaymentTransactionObserver, SKProductsRequestDelegate>

@end

@implementation IAPManager

//在 AppDelgate 中的application: didFinishLaunchingWithOptions: 方法中调用
+ (IAPManager *)getInstance {
    if (instance == nil)
        instance = [[IAPManager alloc] init];
    return instance;
}

//在 AppDelegate 中的applicationWillTerminate：方法中调用
+ (void)releaseInstance
{
    if (instance != nil)
    {
        instance = nil;
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)onTransactionCompleted:(SKPaymentTransaction *)transaction
{
    switch (transaction.transactionState)
    {
        case SKPaymentTransactionStatePurchased:
            [self completeTransaction:transaction];
            break;
        case SKPaymentTransactionStateFailed:
            [self failedTransaction:transaction];
            break;
        case SKPaymentTransactionStateRestored:
            [self restoreTransaction:transaction];     //订阅型和非消耗型的商品才有恢复状态
            break;
        default:
            break;
    }
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    NSInteger errCode = transaction.error.code;
    if(errCode != SKErrorPaymentCancelled)
    {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didCompleteTransaction:error:)])
            [self.delegate didCompleteTransaction:NO error:transaction.error];
    }
    else
    {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didCancelTransaction)])
            [self.delegate didCancelTransaction];
    }
    
    [self finishTransaction:transaction];
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    NSString* orderId = transaction.payment.applicationUsername;
    
    if (orderId == nil) {
        orderId = [self getOrderIdWithProductIdentifier:transaction.payment.productIdentifier];
    }
    
    NSString* transactionId = transaction.transactionIdentifier;
    NSString* transactionReceipt = [[NSString alloc] initWithData:transaction.transactionReceipt encoding:NSUTF8StringEncoding];
    NSInteger count = transaction.payment.quantity;
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //请求后台确认订单
//        HttpRequestIAPOKParam* httpRequest = [[HttpRequestIAPOKParam alloc] init];
//        httpRequest.orderId = orderId;
//        httpRequest.iphoneChargeId = transactionId;
//        httpRequest.receiptData = transactionReceipt;
//        httpRequest.productId = transaction.payment.productIdentifier;
//        httpRequest.count = count;
        
//        NSString * result = [HttpSyncRequest requestWithPostObject:httpRequest];
        NSString *result;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (result != nil)
            {
                NSDictionary* dic /*= [result JSONValue]*/;
                int tagCode = [[dic objectForKey:@"TagCode"] intValue];
                if (dic != nil && tagCode == 0)
                {
                    //业务处理
                    
                    [self finishTransaction:transaction];
                    return;
                }
                else
                {
                    NSLog(@"HttpRequestIAPSuccessParam failed:%d", tagCode);
                    if (tagCode == 5320102 //订单不存在
                        || tagCode == 5320103) //订单已确认成功
                    {
                        //订单在server端已确认成功
                        [self finishTransaction:transaction];
                        return;
                    }
                }
            }
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(didCancelTransaction)])
                [self.delegate didCancelTransaction];
            
//            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:LS(@"Payment completed,confirm the order fails.")
//                                                            message:nil
//                                                           delegate:self
//                                                  cancelButtonTitle:LS(KKTVLocalizationCancel)
//                                                  otherButtonTitles:LS(@"Retry"), LS(@"不再提醒"), nil];
//            alert.userData = transaction;
//            [alert show];
        });
    });
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    if (self.delegate && [self.delegate respondsToSelector:@selector(didRestoreTransaction:)])
        [self.delegate didRestoreTransaction:YES];
}

- (void)finishTransaction:(SKPaymentTransaction *)transaction
{
    [self removeOrderIdWithProductIdentifier:transaction.payment.productIdentifier];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}


#pragma mark - public method
- (BOOL)canMakePurchases
{
    return [SKPaymentQueue canMakePayments];
}

- (void)requestProductsInfo:(NSArray*)prodIds
{
    SKProductsRequest* productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:prodIds]];
    productsRequest.delegate = self;
    [productsRequest start];
}

- (void)purchaseProduct:(SKProduct*)product count:(int)count order:(NSString*)orderId
{
    {
        // 暂存最后一次支付订单的数据
        [self saveDataWithProductIdentifier:product.productIdentifier orderId:orderId];
    }
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    payment.quantity = count;
    payment.applicationUsername = orderId;
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void)restore
{
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(didReceiveProductsResponse:)])
        [self.delegate didReceiveProductsResponse:response.products];
    
}

#pragma mark - SKPaymentTransactionObserver
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        [self onTransactionCompleted:transaction];
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(didRestoreTransaction:)])
        [self.delegate didRestoreTransaction:NO];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(didRestoreTransaction:)])
        [self.delegate didRestoreTransaction:YES];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
    {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didRetryTransaction)])
            [self.delegate didRetryTransaction];
        
//        [self completeTransaction:(SKPaymentTransaction *)alertView.userData];
    }
    else if (buttonIndex == 2)
    {
//        SKPaymentTransaction* transaction = (SKPaymentTransaction*)alertView.userData;
//        NSString* transactionReceipt = [[NSString alloc] initWithData:transaction.transactionReceipt encoding:NSUTF8StringEncoding];
//
//        [self finishTransaction:(SKPaymentTransaction *)alertView.userData];
    }
}

#pragma mark - handle orderId

- (void)saveDataWithProductIdentifier:(NSString *)identifier orderId:(NSString *)orderId {
    if (!identifier || !orderId) {
        return;
    }
    
    NSArray *pathArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [pathArray objectAtIndex:0];
    NSString *filePath = [path stringByAppendingPathComponent:Last_Product_Order_Path];
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithContentsOfFile:filePath];
    if (!dic) {
        dic = [NSMutableDictionary dictionary];
    }
    
    [dic setValue:orderId forKey:identifier];
    
    BOOL flag = [dic writeToFile:filePath atomically:YES];
    if(!flag) {
        NSLog(@"orderId保存失败");
    }
}

- (NSString *)getOrderIdWithProductIdentifier:(NSString *)productIdentifier {
    if (!productIdentifier) {
        return nil;
    }
    
    NSArray *pathArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [pathArray objectAtIndex:0];
    NSString *filePath = [path stringByAppendingPathComponent:Last_Product_Order_Path];
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithContentsOfFile:filePath];
    
    return [dic valueForKey:productIdentifier];
}

- (void)removeOrderIdWithProductIdentifier:(NSString *)productIdentifier {
    if (!productIdentifier) {
        return;
    }
    
    NSArray *pathArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [pathArray objectAtIndex:0];
    NSString *filePath = [path stringByAppendingPathComponent:Last_Product_Order_Path];
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithContentsOfFile:filePath];
    
    [dic removeObjectForKey:productIdentifier];
    
    BOOL flag = [dic writeToFile:filePath atomically:YES];
    if(!flag) {
        NSLog(@"orderId重新保存失败");
    }
}

@end
