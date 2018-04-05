/**
   This module expands each header encountered in the original input file.
   It usually delegates to dstep but not always. Since dstep has a different
   goal, which is to produce human-readable D files from a header, we can't
   just call into it.

   The translate function here will handle the cases it knows how to deal with,
   otherwise it asks dstep to it for us.
 */

module dpp.cursor;

public import dpp.cursor.aggregate;
public import dpp.cursor.function_;
public import dpp.cursor.typedef_;
public import dpp.cursor.macro_;
public import dpp.cursor.enum_;
public import dpp.cursor.variable;
