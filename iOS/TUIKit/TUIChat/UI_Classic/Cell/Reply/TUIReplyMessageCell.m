//
//  TUIReplyMessageCell.m
//  TUIChat
//
//  Created by harvy on 2021/11/11.
//  Copyright © 2023 Tencent. All rights reserved.
//

#import "TUIReplyMessageCell.h"
#import <TIMCommon/NSString+TUIEmoji.h>
#import <TUICore/TUICore.h>
#import <TUICore/TUIDarkModel.h>
#import <TUICore/TUIThemeManager.h>
#import <TUICore/UIView+TUILayout.h>
#import "TUIFileMessageCellData.h"
#import "TUIImageMessageCellData.h"
#import "TUILinkCellData.h"
#import "TUIMergeMessageCellData.h"
#import "TUIReplyMessageCellData.h"
#import "TUITextMessageCellData.h"
#import "TUIVideoMessageCellData.h"
#import "TUIVoiceMessageCellData.h"

#import "TUIFileReplyQuoteView.h"
#import "TUIImageReplyQuoteView.h"
#import "TUIMergeReplyQuoteView.h"
#import "TUIReplyQuoteView.h"
#import "TUITextReplyQuoteView.h"
#import "TUIVideoReplyQuoteView.h"
#import "TUIVoiceReplyQuoteView.h"

#define kReplyQuoteViewMaxWidth 175
#define kReplyQuoteViewMarginWidth 35

@interface TUIReplyMessageCell () <UITextViewDelegate>

@property(nonatomic, strong) TUIReplyQuoteView *currentOriginView;

@property(nonatomic, strong) NSMutableDictionary<NSString *, TUIReplyQuoteView *> *customOriginViewsCache;

@end

@implementation TUIReplyMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    [self.quoteView addSubview:self.senderLabel];
    [self.quoteView.layer addSublayer:self.quoteBorderLayer];

    [self.bubbleView addSubview:self.quoteView];
    [self.bubbleView addSubview:self.textView];

    self.bottomContainer = [[UIView alloc] init];
    [self.contentView addSubview:self.bottomContainer];
}

// Override
- (void)notifyBottomContainerReadyOfData:(TUIMessageCellData *)cellData {
    NSDictionary *param = @{TUICore_TUIChatExtension_BottomContainer_CellData : self.replyData};
    [TUICore raiseExtension:TUICore_TUIChatExtension_BottomContainer_ClassicExtensionID parentView:self.bottomContainer param:param];
}

- (void)fillWithData:(TUIReplyMessageCellData *)data {
    [super fillWithData:data];
    self.replyData = data;
    self.senderLabel.text = [NSString stringWithFormat:@"%@:", data.sender];
    self.textView.attributedText = [data.content getFormatEmojiStringWithFont:self.textView.font emojiLocations:self.replyData.emojiLocations];
    self.bottomContainer.hidden = CGSizeEqualToSize(data.bottomContainerSize, CGSizeZero);
    
    if (data.direction == MsgDirectionIncoming) {
        self.textView.textColor = TUIChatDynamicColor(@"chat_reply_message_content_recv_text_color", @"#000000");
        self.senderLabel.textColor = TUIChatDynamicColor(@"chat_reply_message_quoteView_recv_text_color", @"#888888");
        self.quoteView.backgroundColor = TUIChatDynamicColor(@"chat_reply_message_quoteView_bg_color", @"#4444440c");
    } else {
        self.textView.textColor = TUIChatDynamicColor(@"chat_reply_message_content_text_color", @"#000000");
        self.senderLabel.textColor = TUIChatDynamicColor(@"chat_reply_message_quoteView_text_color", @"#888888");
        self.quoteView.backgroundColor = [UIColor colorWithRed:68 / 255.0 green:68 / 255.0 blue:68 / 255.0 alpha:0.05];
    }

    @weakify(self);
    [[RACObserve(data, originMessage) takeUntil:self.rac_prepareForReuseSignal] subscribeNext:^(V2TIMMessage *originMessage) {
      @strongify(self);
      [self updateUI:data];
      [self layoutIfNeeded];
    }];

    [self layoutIfNeeded];
}

- (void)updateUI:(TUIReplyMessageCellData *)replyData {
    self.currentOriginView = [self getCustomOriginView:replyData.originCellData];
    [self hiddenAllCustomOriginViews:YES];
    self.currentOriginView.hidden = NO;

    [self.currentOriginView fillWithData:replyData.quoteData];

    self.quoteView.mm_x = 16;
    self.quoteView.mm_y = 12;
    self.quoteView.mm_w = self.replyData.quoteSize.width;
    self.quoteView.mm_h = self.replyData.quoteSize.height;

    self.quoteBorderLayer.frame = CGRectMake(0, 0, 3, self.quoteView.mm_h);

    self.textView.mm_y = CGRectGetMaxY(self.quoteView.frame) + 12.0;
    self.textView.mm_x = 18;
    self.textView.mm_w = self.replyData.replyContentSize.width;
    self.textView.mm_h = self.replyData.replyContentSize.height;

    self.senderLabel.mm_x = 6;
    self.senderLabel.mm_y = 3;
    self.senderLabel.mm_w = self.replyData.senderSize.width;
    self.senderLabel.mm_h = self.replyData.senderSize.height;

    self.currentOriginView.mm_y = CGRectGetMaxY(self.senderLabel.frame) + 4;
    self.currentOriginView.mm_x = self.senderLabel.mm_x;
    self.currentOriginView.mm_w = self.replyData.quotePlaceholderSize.width;
    self.currentOriginView.mm_h = self.replyData.quotePlaceholderSize.height;
}

- (TUIReplyQuoteView *)getCustomOriginView:(TUIMessageCellData *)originCellData {
    NSString *reuseId = originCellData ? NSStringFromClass(originCellData.class) : NSStringFromClass(TUITextMessageCellData.class);
    TUIReplyQuoteView *view = nil;
    BOOL reuse = NO;
    if ([self.customOriginViewsCache.allKeys containsObject:reuseId]) {
        view = [self.customOriginViewsCache objectForKey:reuseId];
        reuse = YES;
    }

    if (view == nil) {
        Class class = [originCellData getReplyQuoteViewClass];
        if (class) {
            view = [[class alloc] init];
        }
    }

    if (view == nil) {
        TUITextReplyQuoteView *quoteView = [[TUITextReplyQuoteView alloc] init];
        view = quoteView;
    }

    if ([view isKindOfClass:[TUITextReplyQuoteView class]]) {
        TUITextReplyQuoteView *quoteView = (TUITextReplyQuoteView *)view;
        if (self.replyData.direction == MsgDirectionIncoming) {
            quoteView.textLabel.textColor = TUIChatDynamicColor(@"chat_reply_message_quoteView_recv_text_color", @"#888888");
        } else {
            quoteView.textLabel.textColor = TUIChatDynamicColor(@"chat_reply_message_quoteView_text_color", @"#888888");
        }
    } else if ([view isKindOfClass:[TUIMergeReplyQuoteView class]]) {
        TUIMergeReplyQuoteView *quoteView = (TUIMergeReplyQuoteView *)view;
        if (self.replyData.direction == MsgDirectionIncoming) {
            quoteView.titleLabel.textColor = quoteView.subTitleLabel.textColor =
                TUIChatDynamicColor(@"chat_reply_message_quoteView_recv_text_color", @"#888888");
        } else {
            quoteView.titleLabel.textColor = quoteView.subTitleLabel.textColor = TUIChatDynamicColor(@"chat_reply_message_quoteView_text_color", @"#888888");
        }
    }

    if (!reuse) {
        [self.customOriginViewsCache setObject:view forKey:reuseId];
        [self.quoteView addSubview:view];
    }

    view.hidden = YES;
    return view;
}

- (void)hiddenAllCustomOriginViews:(BOOL)hidden {
    [self.customOriginViewsCache enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, TUIReplyQuoteView *_Nonnull obj, BOOL *_Nonnull stop) {
      obj.hidden = hidden;
      [obj reset];
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [self updateUI:self.replyData];

    [self updateTagView];

    [self layoutBottomContainer];
}

- (void)updateTagView {
    if (self.messageData.messageModifyReactsSize.height > 0) {
        if (self.tagView) {
            CGFloat tagViewTopPadding = 6;
            self.tagView.frame = CGRectMake(0, self.container.mm_h - self.messageData.messageModifyReactsSize.height - tagViewTopPadding,
                                            self.container.frame.size.width, self.messageData.messageModifyReactsSize.height);
        }
    }
}
- (void)layoutBottomContainer {
    if (CGSizeEqualToSize(self.replyData.bottomContainerSize, CGSizeZero)) {
        return;
    }

    CGSize size = self.replyData.bottomContainerSize;
    CGFloat topMargin = self.bubbleView.mm_maxY + self.nameLabel.mm_h + 6;

    if (self.replyData.direction == MsgDirectionOutgoing) {
        self.bottomContainer.mm_top(topMargin).mm_width(size.width).mm_height(size.height).mm_right(self.mm_w - self.container.mm_maxX);
    } else {
        self.bottomContainer.mm_top(topMargin).mm_width(size.width).mm_height(size.height).mm_left(self.container.mm_minX);
    }

    if (!self.messageModifyRepliesButton.hidden) {
        CGRect oldRect = self.messageModifyRepliesButton.frame;
        CGRect newRect = CGRectMake(oldRect.origin.x, CGRectGetMaxY(self.bottomContainer.frame), oldRect.size.width, oldRect.size.height);
        self.messageModifyRepliesButton.frame = newRect;
    }
}

- (UILabel *)senderLabel {
    if (_senderLabel == nil) {
        _senderLabel = [[UILabel alloc] init];
        _senderLabel.text = @"harvy:";
        _senderLabel.font = [UIFont boldSystemFontOfSize:12.0];
        _senderLabel.textColor = TUIChatDynamicColor(@"chat_reply_message_sender_text_color", @"#888888");
    }
    return _senderLabel;
}

- (UIView *)quoteView {
    if (_quoteView == nil) {
        _quoteView = [[UIView alloc] init];
        _quoteView.backgroundColor = TUIChatDynamicColor(@"chat_reply_message_quoteView_bg_color", @"#4444440c");
    }
    return _quoteView;
}

- (CALayer *)quoteBorderLayer {
    if (_quoteBorderLayer == nil) {
        _quoteBorderLayer = [CALayer layer];
        _quoteBorderLayer.backgroundColor = [UIColor colorWithRed:68 / 255.0 green:68 / 255.0 blue:68 / 255.0 alpha:0.1].CGColor;
    }
    return _quoteBorderLayer;
}

- (TUITextView *)textView {
    if (_textView == nil) {
        _textView = [[TUITextView alloc] init];
        _textView.font = [UIFont systemFontOfSize:16.0];
        _textView.textColor = TUIChatDynamicColor(@"chat_reply_message_content_text_color", @"#000000");
        _textView.backgroundColor = [UIColor clearColor];
        _textView.textContainerInset = UIEdgeInsetsMake(0, 0, 0, 0);
        _textView.textContainer.lineFragmentPadding = 0;
        _textView.scrollEnabled = NO;
        _textView.editable = NO;
        _textView.delegate = self;
    }
    return _textView;
}

- (NSMutableDictionary *)customOriginViewsCache {
    if (_customOriginViewsCache == nil) {
        _customOriginViewsCache = [[NSMutableDictionary alloc] init];
    }
    return _customOriginViewsCache;
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
    NSAttributedString *selectedString = [textView.attributedText attributedSubstringFromRange:textView.selectedRange];
    if (self.selectAllContentContent && selectedString) {
        if (selectedString.length == textView.attributedText.length) {
            self.selectAllContentContent(YES);
        } else {
            self.selectAllContentContent(NO);
        }
    }
    if (selectedString.length > 0) {
        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] init];
        [attributedString appendAttributedString:selectedString];
        NSUInteger offsetLocation = 0;
        for (NSDictionary *emojiLocation in self.replyData.emojiLocations) {
            NSValue *key = emojiLocation.allKeys.firstObject;
            NSAttributedString *originStr = emojiLocation[key];
            NSRange currentRange = [key rangeValue];
            currentRange.location += offsetLocation;
            if (currentRange.location >= textView.selectedRange.location) {
                currentRange.location -= textView.selectedRange.location;
                if (currentRange.location + currentRange.length <= attributedString.length) {
                    [attributedString replaceCharactersInRange:currentRange withAttributedString:originStr];
                    offsetLocation += originStr.length - currentRange.length;
                }
            }
        }
        self.selectContent = attributedString.string;
    } else {
        self.selectContent = nil;
    }
}

#pragma mark - TUIMessageCellProtocol
+ (CGFloat)getHeight:(TUIMessageCellData *)data withWidth:(CGFloat)width {
    NSAssert([data isKindOfClass:TUIReplyMessageCellData.class], @"data must be kind of TUIReplyMessageCellData");
    TUIReplyMessageCellData *replyCellData = (TUIReplyMessageCellData *)data;
    
    CGFloat height = [super getHeight:replyCellData withWidth:width];

    if (replyCellData.bottomContainerSize.height > 0) {
        height += replyCellData.bottomContainerSize.height + kScale375(6);
    }

    return height;
}

+ (CGSize)getContentSize:(TUIMessageCellData *)data {
    NSAssert([data isKindOfClass:TUIReplyMessageCellData.class], @"data must be kind of TUIReplyMessageCellData");
    TUIReplyMessageCellData *replyCellData = (TUIReplyMessageCellData *)data;
    
    CGFloat height = 0;
    CGFloat quoteHeight = 0;
    CGFloat quoteWidth = 0;

    CGFloat quoteMinWidth = 100;
    CGFloat quoteMaxWidth = kReplyQuoteViewMaxWidth;
    CGFloat quotePlaceHolderMarginWidth = 12;

    // 动态计算发送者的尺寸
    // Calculate the size of label which displays the sender's displyname
    CGSize senderSize = [@"0" sizeWithAttributes:@{NSFontAttributeName : [UIFont boldSystemFontOfSize:12.0]}];
    CGRect senderRect = [replyCellData.sender boundingRectWithSize:CGSizeMake(quoteMaxWidth, senderSize.height)
                                                  options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                               attributes:@{NSFontAttributeName : [UIFont boldSystemFontOfSize:12.0]}
                                                  context:nil];

    // 动态计算自定义引用占位视图的尺寸
    // Calculate the size of customize quote placeholder view
    CGSize placeholderSize = [replyCellData quotePlaceholderSizeWithType:replyCellData.originMsgType data:replyCellData.quoteData];

    // 动态计算回复内容的尺寸
    // Calculate the size of label which displays the content of replying the original message
    NSAttributedString *attributeString = [replyCellData.content getFormatEmojiStringWithFont:[UIFont systemFontOfSize:16.0] emojiLocations:nil];
    CGRect replyContentRect = [attributeString boundingRectWithSize:CGSizeMake(quoteMaxWidth, CGFLOAT_MAX)
                                                            options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                                            context:nil];

    // 根据内容计算引用视图整体的大小
    // Calculate the size of quote view base the content
    quoteWidth = senderRect.size.width;
    if (quoteWidth < placeholderSize.width) {
        quoteWidth = placeholderSize.width;
    }
    if (quoteWidth < replyContentRect.size.width) {
        quoteWidth = replyContentRect.size.width;
    }
    quoteWidth += quotePlaceHolderMarginWidth;
    if (quoteWidth > quoteMaxWidth) {
        quoteWidth = quoteMaxWidth;
    }
    if (quoteWidth < quoteMinWidth) {
        quoteWidth = quoteMinWidth;
    }
    quoteHeight = 3 + senderRect.size.height + 4 + placeholderSize.height + 6;

    replyCellData.senderSize = CGSizeMake(quoteWidth, senderRect.size.height);
    replyCellData.quotePlaceholderSize = placeholderSize;
    replyCellData.replyContentSize = CGSizeMake(replyContentRect.size.width, replyContentRect.size.height);
    replyCellData.quoteSize = CGSizeMake(quoteWidth, quoteHeight);

    // 计算 cell 的高度
    // Calculate the height of cell
    height = 12 + quoteHeight + 12 + replyCellData.replyContentSize.height + 12;
    return CGSizeMake(quoteWidth + kReplyQuoteViewMarginWidth, height);
}

@end
