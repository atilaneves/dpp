/**
   This module expands each header encountered in the original input file.
   It usually delegates to dstep but not always. Since dstep has a different
   goal, which is to produce human-readable D files from a header, we can't
   just call into it.

   The translate function here will handle the cases it knows how to deal with,
   otherwise it asks dstep to it for us.
 */

module dpp.translation;

public import dpp.translation.aggregate;
public import dpp.translation.function_;
public import dpp.translation.typedef_;
public import dpp.translation.macro_;
public import dpp.translation.enum_;
public import dpp.translation.variable;
