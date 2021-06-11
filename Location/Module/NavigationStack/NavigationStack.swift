//
//  NavigationStack.swift
//
//  Created by Matteo Puccinelli on 28/11/2019.

import SwiftUI

/// Additional Notification names
fileprivate extension Notification.Name {
    /// This notification is being called when navigation animation state changed (push or pop animation, in progress or done)
    static let globalTransactionChanged = Notification.Name("globalTransactionChanged")
}

/// The transition type for the whole NavigationStackView.
public enum NavigationTransition {
    /// Transitions won't be animated.
    case none

    /// Use the [default transition](x-source-tag://defaultTransition).
    case `default`

    /// Use a custom transition (the transition will be applied both to push and pop operations).
    case custom(AnyTransition)

    /// A right-to-left slide transition on push, a left-to-right slide transition on pop.
    /// - Tag: defaultTransition
    public static var defaultTransitions: (push: AnyTransition, pop: AnyTransition) {
        let pushTrans = AnyTransition.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        let popTrans = AnyTransition.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
        return (pushTrans, popTrans)
    }
}

private enum NavigationType {
    case push
    case pop
}

/// Defines the type of a pop operation.
public enum PopDestination {
    /// Pop back to the previous view.
    case previous

    /// Pop back to the root view (i.e. the first view added to the NavigationStackView during the initialization process).
    case root

    /// Pop back to a view identified by a specific ID.
    case view(withId: String)
}

// MARK: ViewModel

public class NavigationStack: ObservableObject {
    fileprivate private(set) var navigationType = NavigationType.push
    /// Customizable easing to apply in pop and push transitions
    private let easing: AnimationType
    static var globalTransaction = false {
        didSet {
            NotificationCenter.default.post(
                name: .globalTransactionChanged,
                object: globalTransaction,
                userInfo: nil
            )
        }
    }
    
    @Published var isTransactionInProgress: Bool = globalTransaction
    
    public init(easing: AnimationType) {
        self.easing = easing
        NotificationCenter.default.addObserver(
            forName: .globalTransactionChanged,
            object: nil,
            queue: nil) { notification in
                self.isTransactionInProgress = notification.object as! Bool
        }
    }
    
    private var viewStack = ViewStack() {
        didSet {
            currentView = viewStack.peek()
        }
    }

    @Published fileprivate var currentView: ViewElement?

    /// Navigates to a view.
    /// - Parameters:
    ///   - element: The destination view.
    ///   - identifier: The ID of the destination view (used to easily come back to it if needed).
    public func push<Element: View>(_ element: Element, withId identifier: String? = nil) {
        lockNestedContent()
        navigationType = .push
        
        viewStack.push(
            ViewElement(
                id: identifier == nil
                    ? UUID().uuidString
                    : identifier!,
                wrappedElement: AnyView(
                    element
                        .animation(easing.animation)
                )
            )
        )
    }

    /// Navigates back to a previous view.
    /// - Parameter to: The destination type of the transition operation.
    public func pop(to: PopDestination = .previous) {
        lockNestedContent()
        navigationType = .pop
        
        switch to {
        case .root:
            viewStack.popToRoot()
        case .view(let viewId):
            viewStack.popToView(withId: viewId)
        default:
            viewStack.popToPrevious()
        }
    }
    
    private func lockNestedContent() {
        if !NavigationStack.globalTransaction {
            NavigationStack.globalTransaction = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + easing.duration) {
                NavigationStack.globalTransaction = false
            }
        }
    }
    
    /// Is navigation stack empty.
    public var isEmpty: Bool {
        viewStack.isEmpty
    }
    
    public func contains(viewID: String) -> Bool {
        viewStack.indexForView(withId: viewID) != nil
    }

    //the actual stack
    private struct ViewStack {
        private var views = [ViewElement]()
        
        var isEmpty: Bool {
            views.isEmpty
        }

        func peek() -> ViewElement? {
            views.last
        }

        mutating func push(_ element: ViewElement) {
            if indexForView(withId: element.id) != nil {
                fatalError("Duplicated view identifier: \"\(element.id)\". You are trying to push a view with an identifier that already exists on the navigation stack.")
            }
            views.append(element)
        }

        mutating func popToPrevious() {
            _ = views.popLast()
        }

        mutating func popToView(withId identifier: String) {
            guard let viewIndex = indexForView(withId: identifier) else {
                fatalError("Identifier \"\(identifier)\" not found. You are trying to pop to a view that doesn't exist.")
            }
            views.removeLast(views.count - (viewIndex + 1))
        }

        mutating func popToRoot() {
            views.removeAll()
        }

        func indexForView(withId identifier: String) -> Int? {
            views.firstIndex {
                $0.id == identifier
            }
        }
    }
}

//the actual element in the stack
private struct ViewElement: Identifiable, Equatable {
    let id: String
    let wrappedElement: AnyView

    static func == (lhs: ViewElement, rhs: ViewElement) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: Views

/// An alternative SwiftUI NavigationView implementing classic stack-based navigation giving also some more control on animations and programmatic navigation.
public struct NavigationStackView<Root>: View where Root: View {
    @ObservedObject private var navViewModel: NavigationStack
    private let rootViewID = "root"
    private let rootView: Root
    private let transitions: (push: AnyTransition, pop: AnyTransition)

    /// Creates a NavigationStackView.
    /// - Parameters:
    ///   - transitionType: The type of transition to apply between views in every push and pop operation.
    ///   - easing: The easing function to apply to every push and pop operation.
    ///   - rootView: The very first view in the NavigationStack.
    public init(transitionType: NavigationTransition = .default, navigationStack: NavigationStack = NavigationStack(easing: .easeOut(duration: 0.35)), @ViewBuilder rootView: () -> Root) {
        self.rootView = rootView()
        self.navViewModel = navigationStack
        switch transitionType {
        case .none:
            self.transitions = (.identity, .identity)
        case .custom(let trans):
            self.transitions = (trans, trans)
        default:
            self.transitions = NavigationTransition.defaultTransitions
        }
    }

    public var body: some View {
        let showRoot = navViewModel.currentView == nil
        let navigationType = navViewModel.navigationType

        return Group {
            if showRoot {
                rootView
                    .id(rootViewID)
                    .transition(navigationType == .push ? transitions.push : transitions.pop)
                    .environmentObject(navViewModel)
            } else {
                navViewModel.currentView!.wrappedElement
                    .id(navViewModel.currentView!.id)
                    .transition(navigationType == .push ? transitions.push : transitions.pop)
                    .environmentObject(navViewModel)
            }
        }.disabled(navViewModel.isTransactionInProgress)
        .animation(.easeInOut)
    }
}

public enum AnimationType {
    // Looks like default time animation in SwiftUI == 0.35
    // To proof it, try to out each type of animation
    // po Animation.default: AnyAnimator(SwiftUI.(unknown context at $7fff2c9bccf4).BezierAnimation(duration: 0.35...
    // po Animation.easeOut: AnyAnimator(SwiftUI.(unknown context at $7fff2c9bccf4).BezierAnimation(duration: 0.35...
    // po Animation.easeIn: AnyAnimator(SwiftUI.(unknown context at $7fff2c9bccf4).BezierAnimation(duration: 0.35...
    // po Animation.easeOut: AnyAnimator(SwiftUI.(unknown context at $7fff2c9bccf4).BezierAnimation(duration: 0.35...
    // po Animation.linear: AnyAnimator(SwiftUI.(unknown context at $7fff2c9bccf4).BezierAnimation(duration: 0.35...
    public static let defaultDuration: Double = 0.35
    
    case easeInOut(duration: Double = defaultDuration)
    case easeIn(duration: Double = defaultDuration)
    case easeOut(duration: Double = defaultDuration)
    case linear(duration: Double = defaultDuration)
    case `default`
    
    var animation: Animation {
        switch self {
        case let .easeIn(duration): return .easeInOut(duration: duration)
        case let .easeInOut(duration): return .easeInOut(duration: duration)
        case let .easeOut(duration): return .easeOut(duration: duration)
        case let .linear(duration): return .linear(duration: duration)
        case .default: return .default
        }
    }
    
    var duration: Double {
        switch self {
        case let .easeIn(duration),
             let .easeInOut(duration),
             let .easeOut(duration),
             let .linear(duration):
            return duration
        case .default:
            return AnimationType.defaultDuration
        }
    }
}
