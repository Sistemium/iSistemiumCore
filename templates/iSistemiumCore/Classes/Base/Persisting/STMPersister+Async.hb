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

#define {{file.queueConst}}_DISPATCH_QUEUE DISPATCH_QUEUE_PRIORITY_DEFAULT


@implementation {{file.className}} ({{file.categoryName}})
{{#each methods}}

- (void){{methodName}}Async:(NSString *)entityName {{parameterName}}:({{parameterType}}){{parameterName}} options:(NSDictionary *)options completionHandler:(STMPersistingAsync{{callbackType}}ResultCallback)completionHandler {

    dispatch_async(dispatch_get_global_queue({{../file.queueConst}}_DISPATCH_QUEUE, 0), ^{

        NSError *error;
        {{#if noResultCallback}}{{else}}{{resultType}} result = {{/if}}[self {{methodName}}Sync:entityName {{parameterName}}:{{parameterName}} options:options error:&error];
        if (completionHandler) {
            [[NSBlockOperation blockOperationWithBlock: ^{
                completionHandler(!error,{{#if noResultCallback}}{{else}} result,{{/if}} error);
            }] start];
        }

    });

}
{{/each}}


#pragma mark - STMPersistingPromised

{{#each methods}}

- (AnyPromise *){{methodName}}:(NSString *)entityName {{parameterName}}:({{parameterType}}){{parameterName}} options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue({{../file.queueConst}}_DISPATCH_QUEUE, 0), ^{

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