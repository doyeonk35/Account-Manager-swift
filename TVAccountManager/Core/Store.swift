import SwiftUI

enum Effect<Action: Sendable>: Sendable {
    case none
    case send(Action)
    case run(@Sendable () async -> Action?)
    case batch([Effect<Action>])
}

@MainActor
final class Store<State, Action: Sendable>: ObservableObject {
    @Published private(set) var state: State

    private let reduce: @MainActor (inout State, Action) -> Effect<Action>

    init(
        initialState: State,
        reducer: @escaping @MainActor (inout State, Action) -> Effect<Action>
    ) {
        self.state = initialState
        self.reduce = reducer
    }

    func send(_ action: Action) {
        let effect = reduce(&state, action)
        handleEffect(effect)
    }

    func binding<Value>(
        get: @escaping (State) -> Value,
        send toAction: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { get(self.state) },
            set: { self.send(toAction($0)) }
        )
    }

    func binding<Value>(
        _ keyPath: KeyPath<State, Value>,
        send toAction: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { self.send(toAction($0)) }
        )
    }

    private func handleEffect(_ effect: Effect<Action>) {
        switch effect {
        case .none:
            break
        case .send(let action):
            send(action)
        case .run(let operation):
            Task { @MainActor in
                if let action = await operation() {
                    self.send(action)
                }
            }
        case .batch(let effects):
            for effect in effects {
                handleEffect(effect)
            }
        }
    }
}
