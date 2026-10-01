import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://jvdcmtgnswphvqucyhcq.supabase.co")!,
    supabaseKey: "sb_publishable_bLhCCHM8ZklNDaBsxCWV4w_DwWU7uGZ",
    options: SupabaseClientOptions(
        auth: .init(emitLocalSessionAsInitialSession: true)
    )
)
