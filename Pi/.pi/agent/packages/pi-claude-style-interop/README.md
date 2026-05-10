# pi-claude-style-interop

Local Pi package that keeps `pi-claude-style-tools` final visual duration rows while removing embedded `✻ Worked for ...` lines from final assistant text blocks.

It also suppresses the live-updating duration row while the final assistant message is still streaming, so the row appears once with the final duration.

This makes newly completed turns copy cleanly with `/copy` without modifying the installed `npm:pi-claude-style-tools` package.
