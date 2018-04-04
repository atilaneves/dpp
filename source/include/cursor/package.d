/**
   This module expands each header encountered in the original input file.
   It usually delegates to dstep but not always. Since dstep has a different
   goal, which is to produce human-readable D files from a header, we can't
   just call into it.

   The translate function here will handle the cases it knows how to deal with,
   otherwise it asks dstep to it for us.
 */

module include.cursor;

public import include.cursor.unit;
public import include.cursor.aggregate;
public import include.type;
public import include.cursor.function_;
public import include.cursor.typedef_;
public import include.cursor.macro_;
public import include.cursor.enum_;
public import include.cursor.variable;
