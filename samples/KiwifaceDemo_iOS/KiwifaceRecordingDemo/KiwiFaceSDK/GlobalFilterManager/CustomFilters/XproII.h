#import "GPUImageFilterGroup.h"
#import "KWRenderProtocol.h"
#import "GPUImage.h"
#import "FourInputFilter.h"

@interface XproIIFilter : GPUImageThreeInputFilter

@end

@interface XproII : GPUImageFilterGroup <KWRenderProtocol>
{
    GPUImagePicture *imageSource1;
    GPUImagePicture *imageSource2;
}

@property(nonatomic, readonly) BOOL needTrackData;

@end
