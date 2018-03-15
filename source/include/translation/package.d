/**
   This module expands each header encountered in the original input file.
   It usually delegates to dstep but not always. Since dstep has a different
   goal, which is to produce human-readable D files from a header, we can't
   just call into it.

   The translate function here will handle the cases it knows how to deal with,
   otherwise it asks dstep to it for us.
 */

module include.translation;

public import include.translation.unit;
public import include.translation.aggregate;
public import include.translation.type;
public import include.translation.function_;
public import include.translation.typedef_;
public import include.translation.macro_;
