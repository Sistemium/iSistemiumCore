//
//  {{file.className}}+{{file.categoryName}}.m
//  iSisSales
//
//  Generated with HandlebarsGenerator on {{meta.date}}
//  Don't edit this file directly!
//
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "{{file.className}}+{{file.categoryName}}.h"

#define {{file.queueConst}}_PROMISED_DISPATCH_QUEUE DISPATCH_QUEUE_PRIORITY_DEFAULT


@implementation {{file.className}} ({{file.categoryName}})
{{#each methods}}

- (AnyPromise *){{methodName}}:(NSString *)entityName {{parameterName}}:({{parameterType}}){{parameterName}} options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue({{../file.queueConst}}_PROMISED_DISPATCH_QUEUE, 0), ^{

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