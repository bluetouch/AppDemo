//
//  User.m
//  AuthDemo
//
//  Created by Teaualune Tseng on 13/5/29.
//  Copyright (c) 2013年 Zencher Co., Ltd. All rights reserved.
//

#import "User.h"

#define APIURL @"http://54.235.170.49:4000"


@interface User ()

+ (void)requestServerWithMethod: (NSString *)method path: (NSString *)path body: (NSString *)body copmletionHandler: (void (^) (NSInteger statusCode, NSData *data, NSError *error))handler;

@end


@implementation User

static User *userSingleton;

+ (User *)currentUser
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        userSingleton = [[User alloc] init];
    });
    return userSingleton;
}

- (id)init
{
    self = [super init];
    if (self) {
        _knownNotValidated = NO;
    }
    return self;
}

- (void)loginWithAccount: (NSString *)account password: (NSString *)password
{
    if (self.loginDelegate == nil) return;
    
    if (self.isKnownNotValidated) {
        [self.loginDelegate loginDidNeedValidate];
        return;
    }

    NSString *path = [NSString stringWithFormat:@"/login?username=%@&password=%@", account, password];
    
    [User requestServerWithMethod:@"GET" path:path body:nil copmletionHandler:^(NSInteger statusCode, NSData *data, NSError *error) {
        if (error != nil) {
            [self.loginDelegate loginDidFailed:@"Login failed with unknown error"];
        } else {
            switch (statusCode) {
                case 200:{
                    [self.loginDelegate loginDidSucceed];
                    break;
                }
                case 403:{
                    [self.loginDelegate loginDidFailed:@"Invalid Username or Password"];
                    break;
                }
                case 506:{
                    [self.loginDelegate loginDidNeedValidate];
                    break;
                }
                default:
                    break;
            }
        }
    }];

}

- (void)logout
{
    _knownNotValidated = NO;
}

- (void)validate: (NSString *)code
{
    NSString *path = [NSString stringWithFormat:@"/validateToken?token=%@", code];
    [User requestServerWithMethod:@"GET" path:path body:nil copmletionHandler:^(NSInteger statusCode, NSData *data, NSError *error) {
        if (error != nil) {
            [self.loginDelegate loginDidFailed:@"Validation failed with unknown error"];
        } else {
            switch (statusCode) {
                case 200:{
                    [self.loginDelegate loginDidSucceed];
                    break;
                }
                case 403:{
                    [self.loginDelegate loginDidFailed:@"Invalid validation"];
                    break;
                }
                case 500:{
                    [self.loginDelegate loginDidFailed:@"Validation failed with unknown error"];
                    break;
                }
                default:
                    break;
            }
        }
    }];
}

- (void)signupWithAccount: (NSString *)account password: (NSString *)password confirm:(NSString *)confirmPassword
{
    if (self.signupDelegate == nil) return;

    if (![password isEqualToString:confirmPassword]) {
        [self.signupDelegate signupDidFailed:@"Re-password is incorrect"];
    } else {
        NSString *body = [NSString stringWithFormat:@"username=%@&password=%@", account, password];
        [User requestServerWithMethod:@"POST" path:@"/signup" body:body copmletionHandler:^(NSInteger statusCode, NSData *data, NSError *error) {
            if (error != nil) {
                [self.signupDelegate signupDidFailed:@"Signup failed with unknow error"];
            } else {
                switch (statusCode) {
                    case 409:{
                        [self.signupDelegate signupDidFailed:@"Duplicate username"];
                        break;
                    }
                    case 500:{
                        [self.signupDelegate signupDidFailed:@"Signup failed with unknow error"];
                        break;
                    }
                    case 506:{
                        [self.signupDelegate signupDidSucceed];
                        break;
                    }
                    default:
                        break;
                }
            }
        }];
    }
}


#pragma mark - private methods

+ (void)requestServerWithMethod: (NSString *)method path: (NSString *)path body: (NSString *)body copmletionHandler: (void (^) (NSInteger statusCode, NSData *data, NSError *error))handler
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[APIURL stringByAppendingString: path]]];
    if ([method isEqualToString:@"GET"]) {
    } else if ([method isEqualToString:@"POST"]) {
        request = [[NSMutableURLRequest alloc] init];
        request.HTTPMethod = @"POST";
    }
    if (body != nil) {
        request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue new] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger statusCode = ((NSHTTPURLResponse *) response).statusCode;
            handler(statusCode, data, error);
        });
    }];
}

@end
