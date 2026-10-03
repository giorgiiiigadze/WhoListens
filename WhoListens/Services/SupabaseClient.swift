import Foundation
import Supabase

let supabaseURL = URL(string: "https://jvdcmtgnswphvqucyhcq.supabase.co")!
let supabasePublishableKey = "sb_publishable_bLhCCHM8ZklNDaBsxCWV4w_DwWU7uGZ"

let supabase = SupabaseClient(
    supabaseURL: supabaseURL,
    supabaseKey: supabasePublishableKey,
    options: SupabaseClientOptions(
        auth: .init(emitLocalSessionAsInitialSession: true)
    )
)
