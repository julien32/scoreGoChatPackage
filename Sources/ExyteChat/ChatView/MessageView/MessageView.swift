//
//  MessageView.swift
//  Chat
//
//  Created by Alex.M on 23.05.2022.
//

import SwiftUI

struct MessageView: View {

    @Environment(\.chatTheme) private var theme

    @ObservedObject var viewModel: ChatViewModel
    
    let deepLinks = DeepLinks.deepLinks

    let message: Message
    let positionInGroup: PositionInGroup
    let avatarSize: CGFloat
    let messageUseMarkdown: Bool
    let isDisplayingMessageMenu: Bool

    @State var avatarViewSize: CGSize = .zero
    @State var statusSize: CGSize = .zero
    @State var timeSize: CGSize = .zero

    static let widthWithMedia: CGFloat = 204
    static let horizontalAvatarPadding: CGFloat = 8
    static let horizontalTextPadding: CGFloat = 12
    static let statusViewSize: CGFloat = 14
    static let horizontalStatusPadding: CGFloat = 8
    static let horizontalBubblePadding: CGFloat = 70

    let font = UIFont.systemFont(ofSize: 15)

    enum DateArrangment {
        case hstack, vstack, overlay
    }

    var dateArrangment: DateArrangment {
        let timeWidth = timeSize.width + 10
        let textPaddings = MessageView.horizontalTextPadding * 2
        let widthWithoutMedia = UIScreen.main.bounds.width
        - avatarViewSize.width
        - statusSize.width
        - MessageView.horizontalBubblePadding
        - textPaddings
        let maxWidth = message.attachments.isEmpty ? widthWithoutMedia : MessageView.widthWithMedia - textPaddings
        let finalWidth = message.text.width(withConstrainedWidth: maxWidth, font: font, messageUseMarkdown: messageUseMarkdown)
        let lastLineWidth = message.text.lastLineWidth(labelWidth: maxWidth, font: font, messageUseMarkdown: messageUseMarkdown)
        let numberOfLines = message.text.numberOfLines(labelWidth: maxWidth, font: font, messageUseMarkdown: messageUseMarkdown)

        if numberOfLines == 1, finalWidth + CGFloat(timeWidth) < maxWidth {
            return .hstack
        }
        if lastLineWidth + CGFloat(timeWidth) < finalWidth {
            return .overlay
        }
        return .vstack
    }

    var showAvatar: Bool {
        positionInGroup == .single || positionInGroup == .last
    }

    var topPadding: CGFloat {
        positionInGroup == .first || positionInGroup == .single ? 8 : 4
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if !message.user.isCurrentUser {
                avatarView
            }

            VStack(alignment: message.user.isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isDisplayingMessageMenu, let reply = message.replyMessage?.toMessage() {
                    HStack(spacing: 8) {
                        Capsule()
                            .foregroundColor(theme.colors.buttonBackground)
                            .frame(width: 2)
                        replyBubbleView(reply)
                    }
                }
                bubbleView(message)
            }

            if message.user.isCurrentUser, let status = message.status {
                MessageStatusView(status: status) {
                    if case let .error(draft) = status {
                        viewModel.sendMessage(draft)
                    }
                }
                .sizeGetter($statusSize)
            }
        }
        .padding(.top, topPadding)
        .padding(message.user.isCurrentUser ? .leading : .trailing, MessageView.horizontalBubblePadding)
        .frame(maxWidth: UIScreen.main.bounds.width, alignment: message.user.isCurrentUser ? .trailing : .leading)
    }

    @ViewBuilder
    func bubbleView(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !message.attachments.isEmpty {
                attachmentsView(message)
            }

            if !message.text.isEmpty {
//                DeepLinks.deepLinks.checkDeepLink(message.text)
                if deepLinks.checkIfDeepLink(message.text) {
                    DeepLinks.deepLinks.createDeepLinkView(message.text)
                        .padding()
                } else {
                    textWithTimeView(message)
                        .font(Font(font))
                }
            }

            if let recording = message.recording {
                VStack(alignment: .trailing, spacing: 8) {
                    recordingView(recording)
                    messageTimeView()
                        .padding(.bottom, 8)
                        .padding(.trailing, 12)
                }
            }
        }
        .bubbleBackground(message, theme: theme)
    }

    @ViewBuilder
    func replyBubbleView(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(message.user.name)
                .fontWeight(.semibold)
                .padding(.horizontal, MessageView.horizontalTextPadding)

            if !message.attachments.isEmpty {
                attachmentsView(message)
                    .padding(.top, 4)
                    .padding(.bottom, message.text.isEmpty ? 0 : 4)
            }

            if !message.text.isEmpty {
                MessageTextView(text: message.text, messageUseMarkdown: messageUseMarkdown)
                    .padding(.horizontal, MessageView.horizontalTextPadding)
            }

            if let recording = message.recording {
                recordingView(recording)
            }
        }
        .font(.caption2)
        .padding(.vertical, 8)
        .frame(width: message.attachments.isEmpty ? nil : MessageView.widthWithMedia)
        .bubbleBackground(message, theme: theme, isReply: true)
    }

    @ViewBuilder
    var avatarView: some View {
        Group {
            if showAvatar {
                AvatarView(url: message.user.avatarURL, avatarSize: avatarSize)
            } else {
                Color.clear.viewSize(avatarSize)
            }
        }
        .padding(.horizontal, MessageView.horizontalAvatarPadding)
        .sizeGetter($avatarViewSize)
    }

    @ViewBuilder
    func attachmentsView(_ message: Message) -> some View {
        AttachmentsGrid(attachments: message.attachments) {
            viewModel.presentAttachmentFullScreen($0)
        }
        .overlay(alignment: .bottomTrailing) {
            if message.text.isEmpty {
                messageTimeView(needsCapsule: true)
                    .padding(4)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    func textWithTimeView(_ message: Message) -> some View {
        let messageView = MessageTextView(text: message.text, messageUseMarkdown: messageUseMarkdown)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, MessageView.horizontalTextPadding)

        let timeView = messageTimeView()
            .padding(.trailing, 12)

        Group {
            switch dateArrangment {
            case .hstack:
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    messageView
                    if !message.attachments.isEmpty {
                        Spacer()
                    }
                    timeView
                }
                .padding(.vertical, 8)
            case .vstack:
                VStack(alignment: .leading, spacing: 4) {
                    messageView
                    HStack(spacing: 0) {
                        Spacer()
                        timeView
                    }
                }
                .padding(.vertical, 8)
            case .overlay:
                messageView
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottomTrailing) {
                        timeView
                            .padding(.vertical, 8)
                    }
            }
        }
    }

    @ViewBuilder
    func recordingView(_ recording: Recording) -> some View {
        RecordWaveformWithButtons(
            recording: recording,
            colorButton: message.user.isCurrentUser ? theme.colors.myMessage : .white,
            colorButtonBg: message.user.isCurrentUser ? .white : theme.colors.myMessage,
            colorWaveform: message.user.isCurrentUser ? theme.colors.textDarkContext : theme.colors.textLightContext
        )
        .padding(.horizontal, MessageView.horizontalTextPadding)
        .padding(.top, 8)
    }

    func messageTimeView(needsCapsule: Bool = false) -> some View {
        Group {
            if needsCapsule {
                MessageTimeWithCapsuleView(text: message.time, isCurrentUser: message.user.isCurrentUser)
            } else {
                MessageTimeView(text: message.time, isCurrentUser: message.user.isCurrentUser)
            }
        }
        .sizeGetter($timeSize)
    }
}

extension View {

    @ViewBuilder
    func bubbleBackground(_ message: Message, theme: ChatTheme, isReply: Bool = false) -> some View {
        let radius: CGFloat = !message.attachments.isEmpty ? 12 : 20
        self
            .frame(width: message.attachments.isEmpty ? nil : MessageView.widthWithMedia)
            .foregroundColor(message.user.isCurrentUser ? theme.colors.textDarkContext : theme.colors.textLightContext)
            .background {
                if isReply || !message.text.isEmpty || message.recording != nil {
                    RoundedRectangle(cornerRadius: radius)
                        .foregroundColor(message.user.isCurrentUser ? theme.colors.myMessage : theme.colors.friendMessage)
                        .opacity(isReply ? 0.5 : 1)
                }
            }
            .cornerRadius(radius)
    }
}

#if DEBUG
struct MessageView_Preview: PreviewProvider {
    static private var shortMessage = "Hi, buddy!"
    static private var longMessage = "Hello hello hello hello hello hello hello hello hello hello hello hello hello\n hello hello hello hello d d d d d d d d"

    static private var message = Message(
        id: UUID().uuidString,
        user: User(id: UUID().uuidString, name: "Stan", avatarURL: nil, isCurrentUser: false),
        status: .read,
        text: longMessage,
        attachments: [
            Attachment.randomImage(),
            Attachment.randomImage(),
            Attachment.randomImage(),
            Attachment.randomImage(),
            Attachment.randomImage(),
        ]
    )

    static var previews: some View {
        MessageView(
            viewModel: ChatViewModel(),
            message: message,
            positionInGroup: .single,
            avatarSize: 32,
            messageUseMarkdown: false,
            isDisplayingMessageMenu: false
        )
    }
}
#endif

public enum SpecificMessageType : String {
    case playerDetails
    case tournamentDetails
    case detailedEvent
    case newsArticle
    case privateTippingGame
    case officialTippingGame
    case none
}

public class DeepLinks {
    public static let deepLinks = DeepLinks()
    
    private var url = "scorego://"
    private var firstQuery = "?id="
    private var test = ""
    
    public func checkIfDeepLink(_ link : String) -> Bool {
        return link.contains(url)
    }
    
    public func getDeepLinkType(_ link : String) -> SpecificMessageType {
        guard let startIndex = link.range(of: "scorego://")?.upperBound,
              let endIndex = link.range(of: "?")?.lowerBound else {
            return .none
        }
            
            let extractedText = String(link[startIndex..<endIndex])
        
        if let type = SpecificMessageType(rawValue: extractedText) {
            return type
        } else {
            return .none
        }
    }
    
    public func getTitleOfQueryString(_ link : String) -> String {
        guard let startIndex = link.range(of: "title=")?.upperBound else {
            return ""
        }
        
        return String(link[startIndex..<link.endIndex])
    }
    
    func createDeepLinkView(_ link : String) -> Link<Text> {
        
        return Link(destination: URL(string: link)!, label: {
            Text(getTitleOfQueryString(link))
                .fontWeight(.bold)
                .font(.title3)
        })
    }
}
