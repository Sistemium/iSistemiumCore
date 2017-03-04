//
//  {{file.className}}+{{file.categoryName}}.m
//  iSisSales
//
//  Generated with HandlebarsGenerator
//  Don't edit this file directly!
//
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "{{file.className}}+{{file.categoryName}}.h"


@implementation {{file.className}} ({{file.categoryName}})
{{#each methods}}

- (void){{methodName}}Async:(NSString *)entityName {{parameterName}}:({{parameterType}}){{parameterName}} options:(NSDictionary *)options completionHandler:(STMPersistingAsync{{callbackType}}ResultCallback)completionHandler {

    dispatch_async(self.dispatchQueue, ^{

        NSError *error;
        {{#if noResultCallback}}{{else}}{{resultType}} result = {{/if}}[self {{methodName}}Sync:entityName {{parameterName}}:{{parameterName}} options:options error:&error];
        if (completionHandler) {
            dispatch_async(self.dispatchQueue, ^{
                completionHandler(!error,{{#if noResultCallback}}{{else}} result,{{/if}} error);
            });
        }

    });

}
{{/each}}


#pragma mark - STMPersistingPromised

{{#each methods}}

- (AnyPromise *){{methodName}}:(NSString *)entityName {{parameterName}}:({{parameterType}}){{parameterName}} options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(self.dispatchQueue, ^{

            NSError *error;
            {{#if resultType}}{{resultType}} result = {{/if}}[self {{methodName}}Sync:entityName {{parameterName}}:{{parameterName}} options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve({{#if isPrimitive}}@(result){{else}}result{{/if}});
            }

        });
    }];

}
{{/each}}

@end