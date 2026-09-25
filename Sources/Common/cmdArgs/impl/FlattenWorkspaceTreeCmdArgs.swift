public struct FlattenWorkspaceTreeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .flattenWorkspaceTree,
        help: flatten_workspace_tree_help_generated,
        flags: [
            "--workspace": workspaceSubArgParser(),
            "--container": trueBoolFlag(\.container),
        ],
        posArgs: [],
    )

    /// Fork addition. Flatten only the focused window's parent tiling
    /// container instead of the whole workspace, so a nested group can be
    /// reset without disturbing the rest of the layout. When the focused
    /// window is already a direct child of the root the two are equivalent,
    /// which gives "reset my container, or the workspace if I'm at the top
    /// level" for free.
    public var container: Bool = false
}
