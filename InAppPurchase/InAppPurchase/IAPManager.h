//
//  IAPManager.h
//  NewTest
//
//  Created by mac on 2019/7/11.
//  Copyright © 2019 MyCompany. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@protocol IAPManagerDelegate <NSObject>

- (void)didReceiveProductsResponse:(NSArray *)products;
- (void)didCompleteTransaction:(BOOL)bSuccess error:(NSError *)error;
- (void)didCancelTransaction;
- (void)didRetryTransaction;

@optional
- (void)didCompleteTransactionOK:(NSString*)orderId amount:(NSInteger)amount;
- (void)didRestoreTransaction:(BOOL)bSuccess;
- (void)didAutoRenewCompleteOK:(BOOL)bSuccess error:(NSError *)error;
- (void)didAutoRenewHadBought;


@end

@interface IAPManager : NSObject
@property (nonatomic, weak) id<IAPManagerDelegate> delegate;

+ (IAPManager *)getInstance;
+ (void)releaseInstance;
- (BOOL)canMakePurchases;
- (void)requestProductsInfo:(NSArray*)prodIds;
- (void)purchaseProduct:(SKProduct*)product count:(int)count order:(NSString*)orderId;
- (void)restore;

@end


