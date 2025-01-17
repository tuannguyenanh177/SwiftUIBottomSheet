//
//  BottomSheetModifier.swift
//  MasterMind
//
//  Created by Anna Sidorova on 23.07.2021.
//

import Foundation
import SwiftUI
import Combine

public extension UIColor {
    static var bottomSheetOverlay: UIColor = .init {
        if $0.userInterfaceStyle == .dark {
            return .white
        } else {
            return .black
        }
    }
}

public struct BottomSheetConfig {

    public init(maxHeight: CGFloat = 600,
                kind: Kind = .interactiveDismiss,
                overlayColor: Color = .init(.bottomSheetOverlay),
                shadow: Color? = .init(.black).opacity(0.4),
                background: Color = .init(.systemBackground),
                handleColor: Color = .init(.lightGray),
                handlePosition: HandlePosition = .inside,
                topBarCornerRadius: CGFloat? = nil,
                sizeChangeRequest: Binding<CGFloat> = .constant(0),
                isIgnoreKeyboardInset: Bool = false,
                animation: Animation = .interactiveSpring()) {
        self.maxHeight = maxHeight
        self.kind = kind
        self.overlayColor = overlayColor
        self.shadow = shadow
        self.background = background
        self.handleColor = handleColor
        self.handlePosition = handlePosition
        self.topBarCornerRadius = topBarCornerRadius
        self.sizeChangeRequest = sizeChangeRequest
        self.isIgnoreKeyboardInset = isIgnoreKeyboardInset
        self.animation = animation
    }

    public enum Kind: Int, CaseIterable, Equatable {
        case `static`
        case tapDismiss

        case resizable
        case interactiveDismiss
    }

    public enum HandlePosition: Int {
        case inside
        case outside
    }

    public var maxHeight: CGFloat
    public var kind: Kind
    public var overlayColor: Color
    public var shadow: Color?
    public var background: Color
    public var handleColor: Color
    public var handlePosition: HandlePosition
    public var topBarCornerRadius: CGFloat?
    public var sizeChangeRequest: Binding<CGFloat>
    public var isIgnoreKeyboardInset: Bool
    public var animation: Animation
}

public extension BottomSheetConfig {
    func feedback(into binding: Binding<CGFloat>) -> Self {
        var copy = self
        copy.sizeChangeRequest = binding
        return copy
    }
}

public extension View {

    func bottomSheet<Content: View>(isPresented: Binding<Bool>,
                                    config: BottomSheetConfig,
                                    @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(BottomSheetModifier(isSheetPresented: isPresented,
                                     config: config,
                                     sheetContent: content))
    }

    func bottomSheet<Content: View>(isPresented: Binding<Bool>,
                                    maxHeight: CGFloat = 600,
                                    useGesture: Bool = true,
                                    @ViewBuilder content: @escaping () -> Content) -> some View {

        bottomSheet(isPresented: isPresented,
                    config: .init(maxHeight: maxHeight,
                                  kind: useGesture ? .interactiveDismiss : .static),
                    content: content)
    }

    func bottomSheet<Content: View, T>(item: Binding<T?>,
                                       config: BottomSheetConfig,
                                       content: @escaping (T) -> Content) -> some View {
        modifier(
            BottomSheetModifier(
                isSheetPresented: item.asBool(),
                config: config,
                sheetContent: {
                    if let value = item.wrappedValue {
                        content(value)
                    } else {
                        EmptyView()
                    }
                }
            )
        )
    }

    func bottomSheet<Content: View, T>(item: Binding<T?>,
                                       maxHeight: CGFloat = 600,
                                       useGesture: Bool = true,
                                       @ViewBuilder content: @escaping (T) -> Content) -> some View {
        bottomSheet(item: item,
                    config: .init(maxHeight: maxHeight,
                                  kind: useGesture ? .interactiveDismiss : .static),
                    content: content)
    }
}

private struct BottomSheetModifier<SheetContent: View>: ViewModifier {
    @Binding
    fileprivate var isSheetPresented: Bool

    let config: BottomSheetConfig
    @ViewBuilder
    fileprivate let sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        content
            .presentation(isPresenting: $isSheetPresented) {
                BottomSheetContainer(isPresented: $isSheetPresented,
                                     config: config,
                                     content: sheetContent)
            }
    }
}

private struct BottomSheetContainer<Content: View>: View {

    private var dragToDismissThreshold: CGFloat { min(100, max(0, height - 50)) }
    private var grayBackgroundOpacity: Double { shown ? 0.4 : 0 }

    @State
    private var draggedOffset: CGFloat = 0

    @Binding
    private var isPresented: Bool
    private let config: BottomSheetConfig

    private let content: Content

    private let topBarHeight: CGFloat = 30
    private let topBarCornerRadius: CGFloat

    var canDrag: Bool {
        config.kind == .interactiveDismiss || config.kind == .resizable
    }

    var canDismiss: Bool {
        config.kind == .tapDismiss || config.kind == .interactiveDismiss
    }

    public init(
        isPresented: Binding<Bool>,
        config: BottomSheetConfig,
        content: () -> Content
    ) {
        self._isPresented = isPresented

        self.config = config

        if let topBarCornerRadius = config.topBarCornerRadius {
            self.topBarCornerRadius = topBarCornerRadius
        } else {
            self.topBarCornerRadius = topBarHeight / 2
        }
        self.content = content()
    }

    @Environment(\.screenTransition)
    private var transition

    @State
    private var shown: Bool = false

    @State
    private var appear = false

    public var body: some View {
        GeometryReader { geometry in
            fullScreenLightGrayOverlay()
                .overlay(
                    sheetContentContainer(geometry: geometry), alignment: .bottom
                )
        }
        .shouldIgnoreKeyboardInset(value: config.isIgnoreKeyboardInset)
        .onReceive(Just(isPresented && transition.phase == .live && appear)) { newValue in
            guard newValue != shown else { return }

            withAnimation(transition.animation) {
                shown = newValue
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                appear = true
            }
        }
    }

    @ViewBuilder
    fileprivate func fullScreenLightGrayOverlay() -> some View {
        config.overlayColor
            .opacity(shown ? grayBackgroundOpacity : 0)
            .edgesIgnoringSafeArea(.all)
            .onTapGesture {
                guard canDismiss else { return }

                isPresented = false
            }
    }

    @ViewBuilder
    func sheetContentContainer(geometry: GeometryProxy) -> some View {
        let offset = shown
        ? draggedOffset
        : (height + geometry.safeAreaInsets.bottom + 10) // 10 is for shadows

        Group {
            if let shadowColor = config.shadow {
                sheetContent(geometry: geometry)
                    .background(
                        RoundedCorner(radius: topBarCornerRadius, corners: [.topLeft, .topRight])
                            .foregroundColor(config.background)
                            .edgesIgnoringSafeArea(.bottom)
                            .shadow(color: shadowColor, radius: 10, x: 0, y: 0)
                    )
            } else {
                sheetContent(geometry: geometry)
            }
        }
        .offset(y: offset)
        .animation(shown ? config.animation : nil, value: height)
        .animation(config.animation, value: dragEnded)
        .animation(config.animation, value: config.handlePosition)
        .transaction {
            if dragStart != nil {
                $0.animation = config.animation
            }
        }
    }

    @State
    private var size: CGSize = .zero

    var height: CGFloat {
        size.height
    }

    @ViewBuilder
    func sheetContent(geometry: GeometryProxy) -> some View {
        let shift = config.handlePosition == .inside && canDrag ? 0 : topBarHeight

        let clipShape = RoundedCorner(radius: topBarCornerRadius, corners: [.topLeft, .topRight])

        let sheetHeight = max(0, height - shift + topBarHeight)

        ZStack(alignment: .top) {
            content
                .geometryFetch(size: $size)
                .frame(height: height, alignment: .top)
                .padding(.top, topBarHeight - shift)
                .clipShape(clipShape)
                .frame(height: sheetHeight, alignment: .top)

            topBar(geometry: geometry)
                .padding(.top, -shift)
                .frame(height: sheetHeight, alignment: .top)
        }
        .background(
            config.background
                .frame(height: sheetHeight + 6000, alignment: .top)
                .clipShape(clipShape)
            , alignment: .top
        )
    }

    @State
    private var dragStart: CGFloat?

    @State
    private var dragEnded = false

    @ViewBuilder
    fileprivate func topBar(geometry: GeometryProxy) -> some View {
        if canDrag {
            BlurView(tintAlpha: 0)
                    .frame(width: 40, height: 6)
                    .overlay(Color(.lightGray).opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(width: geometry.size.width, height: topBarHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let offsetY = value.translation.height
                        if let dragStart = dragStart {
                            self.draggedOffset = offsetY - dragStart
                        } else {
                            dragStart = offsetY
                        }
                    }
                    .onEnded { value in
                        if canDismiss && draggedOffset > dragToDismissThreshold {
                            isPresented = false
                        } else {
                            config.sizeChangeRequest.wrappedValue = height - topBarHeight - draggedOffset

                            dragEnded.toggle()

                            draggedOffset = 0
                        }

                        dragStart = nil
                    }
            )
        } else {
            ZStack { }
            .frame(width: geometry.size.width, height: topBarHeight)
            .contentShape(Rectangle())
        }
    }
}


public struct BottomSheet_Preview: PreviewProvider {

    public struct Preview: View {
        @State var isShown = false
        @State var height: Double = 100.0

        public init() {}

        public var body: some View {
            ZStack {
                Color.yellow
                Button("Booo") {
                    height = height == 100.0 ? 400.0 : 100.0
                    isShown = true
                }
            }
            .bottomSheet(isPresented: $isShown) {
                VStack {
                    OvergrowScrollView(maxHeight: 400) {
                        ZStack {
                            Color.red
                        }
                        .frame(width: 300, height: height)
                    }

                    Color.blue
                        .frame(height: 100)
                }
            }
        }
    }

    public static var previews: some View {
        Preview()
    }
}

struct AnimatableModifierDouble: AnimatableModifier {

    var targetValue: Double

    var animatableData: Double {
        didSet {
            checkIfFinished()
        }
    }

    var completion: () -> ()

    init(bindedValue: Double, completion: @escaping () -> ()) {
        self.completion = completion
        self.animatableData = bindedValue
        targetValue = bindedValue
    }

    func checkIfFinished() -> () {
        if (animatableData == targetValue) {
            DispatchQueue.main.async {
                self.completion()
            }
        }
    }

    func body(content: Content) -> some View {
        content
    }
}

private extension GeometryReader {
  @ViewBuilder
  func shouldIgnoreKeyboardInset(value: Bool) -> some View {
    if value {
      if #available(iOS 14.0, *) {
        self.ignoresSafeArea(.keyboard, edges: .bottom)
      } else {
        self
      }
    } else {
      self
    }
  }
}
