import AppKit
import Common

struct FlattenWorkspaceTreeCommand: Command {
    let args: FlattenWorkspaceTreeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        let workspace = target.workspace

        // Fork addition: --container narrows the flatten to the focused
        // window's parent tiling container. Falls back to the workspace root
        // for a floating or unbound window, and note that a window whose
        // parent IS the root makes the two paths identical — so the same
        // binding means "reset this container, or the whole workspace when
        // I'm already at the top level".
        var root = workspace.rootTilingContainer
        if args.container {
            guard let window = target.windowOrNil else {
                return .fail(io.err(noWindowIsFocused))
            }
            if case .tilingContainer(let parent) = window.windowParentCases {
                root = parent
            }
        }

        let windows = root.allLeafWindowsRecursive
        for window in windows {
            window.bind(to: root, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        }
        return .succ
    }
}
