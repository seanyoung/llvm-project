//===----------------------------------------------------------------------===//
// Vector Instructions
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Instructions
//
// Define all vector instructions defined in SX-Aurora TSUBASA Architecture
// Guide here.  As those mnemonics, we use mnemonics defined in Vector Engine
// Assembly Language Reference Manual.
//
// Some instructions can update existing data by following instructions
// sequence.
//
//   lea %s0, 256
//   lea %s1, 128
//   lvl %s0
//   vbrd %v0, 2 # v0 = { 2, 2, 2, ..., 2, 2, 2 }
//   lvl %s1
//   vbrd %v0, 3 # v0 = { 3, 3, 3, ..., 3, 2, 2, 2, ..., 2, 2, 2 }
//
// In order to represent above with a virtual register, we defines instructions
// with an additional base register and `_v` suffiex in mnemonic.
//
//   lea t0, 256
//   lea t1, 128
//   lea t0
//   vbrd tv0, 2
//   lvl t1
//   vbrd_v tv1, 2, tv0
//
// We also have some instructions uses VL register with an pseudo VL value
// with following suffixes in mnemonic.
//
//   l: have an additional I32 register to represent the VL value.
//   L: have an additional VL register to represent the VL value.
//===----------------------------------------------------------------------===//

//-----------------------------------------------------------------------------
// Section 8.9 - Vector Load/Store and Move Instructions
//-----------------------------------------------------------------------------

// Multiclass for VLD instructions
let mayLoad = 1, hasSideEffects = 0, Uses = [VL] in
multiclass VLDbm<string opcStr, bits<8>opc, RegisterClass RC, dag dag_in,
                 string disEnc = ""> {
  let DisableEncoding = disEnc in
  def "" : RVM<opc, (outs RC:$vx), dag_in,
               !strconcat(opcStr, " $vx, $sy, $sz")>;
  let Constraints = "$vx = $base", DisableEncoding = disEnc#"$base",
      isCodeGenOnly = 1 in
  def _v : RVM<opc, (outs RC:$vx), !con(dag_in, (ins RC:$base)),
               !strconcat(opcStr, " $vx, $sy, $sz")>;
}
multiclass VLDlm<string opcStr, bits<8>opc, RegisterClass RC, dag dag_in> {
  defm "" : VLDbm<opcStr, opc, RC, dag_in>;
  let isCodeGenOnly = 1, VE_VLInUse = 1 in {
    defm l : VLDbm<opcStr, opc, RC, !con(dag_in, (ins I32:$vl)), "$vl,">;
    defm L : VLDbm<opcStr, opc, RC, !con(dag_in, (ins VLS:$vl)), "$vl,">;
  }
}
let VE_VLIndex = 3 in
multiclass VLDtgm<string opcStr, bits<8>opc, RegisterClass RC> {
  defm rr : VLDlm<opcStr, opc, RC, (ins I64:$sy, I64:$sz)>;
  let cy = 0 in
  defm ir : VLDlm<opcStr, opc, RC, (ins simm7:$sy, I64:$sz)>;
  let cz = 0 in
  defm rz : VLDlm<opcStr, opc, RC, (ins I64:$sy, zero:$sz)>;
  let cy = 0, cz = 0 in
  defm iz : VLDlm<opcStr, opc, RC, (ins simm7:$sy, zero:$sz)>;
}
multiclass VLDm<string opcStr, bits<8>opc, RegisterClass RC> {
  let vc = 1 in defm "" : VLDtgm<opcStr, opc, RC>;
  let vc = 0 in defm NC : VLDtgm<opcStr#".nc", opc, RC>;
}

// Section 8.9.1 - VLD (Vector Load)
defm VLD : VLDm<"vld", 0x81, V64>;

// Section 8.9.2 - VLDU (Vector Load Upper)
defm VLDU : VLDm<"vldu", 0x82, V64>;

// Section 8.9.3 - VLDL (Vector Load Lower)
defm VLDLSX : VLDm<"vldl.sx", 0x83, V64>;
let cx = 1 in defm VLDLZX : VLDm<"vldl.zx", 0x83, V64>;

// Section 8.9.4 - VLD2D (Vector Load 2D)
defm VLD2D : VLDm<"vld2d", 0xc1, V64>;

// Section 8.9.5 - VLDU2D (Vector Load Upper 2D)
defm VLDU2D : VLDm<"vldu2d", 0xc2, V64>;

// Section 8.9.6 - VLDL2D (Vector Load Lower 2D)
defm VLDL2DSX : VLDm<"vldl2d.sx", 0xc3, V64>;
let cx = 1 in defm VLDL2DZX : VLDm<"vldl2d.zx", 0xc3, V64>;

// Multiclass for VST instructions
let mayStore = 1, hasSideEffects = 0, Uses = [VL] in
multiclass VSTbm<string opcStr, string argStr, bits<8>opc, dag dag_in> {
  def "" : RVM<opc, (outs), dag_in, !strconcat(opcStr, argStr)>;
  let DisableEncoding = "$vl", isCodeGenOnly = 1, VE_VLInUse = 1 in {
    def l : RVM<opc, (outs), !con(dag_in, (ins I32:$vl)),
                !strconcat(opcStr, argStr)>;
    def L : RVM<opc, (outs), !con(dag_in, (ins VLS:$vl)),
                !strconcat(opcStr, argStr)>;
  }
}
multiclass VSTmm<string opcStr, bits<8>opc, dag dag_in> {
  defm "" : VSTbm<opcStr, " $vx, $sy, $sz", opc, dag_in>;
  let m = ?, VE_VLWithMask = 1 in
  defm m : VSTbm<opcStr, " $vx, $sy, $sz, $m", opc, !con(dag_in, (ins VM:$m))>;
}
let VE_VLIndex = 3 in
multiclass VSTtgm<string opcStr, bits<8>opc, RegisterClass RC> {
  defm rrv : VSTmm<opcStr, opc, (ins I64:$sy, I64:$sz, RC:$vx)>;
  let cy = 0 in
  defm irv : VSTmm<opcStr, opc, (ins simm7:$sy, I64:$sz, RC:$vx)>;
  let cz = 0 in
  defm rzv : VSTmm<opcStr, opc, (ins I64:$sy, zero:$sz, RC:$vx)>;
  let cy = 0, cz = 0 in
  defm izv : VSTmm<opcStr, opc, (ins simm7:$sy, zero:$sz, RC:$vx)>;
}
multiclass VSTm<string opcStr, bits<8>opc, RegisterClass RC> {
  let vc = 1, cx = 0 in defm "" : VSTtgm<opcStr, opc, RC>;
  let vc = 0, cx = 0 in defm NC : VSTtgm<opcStr#".nc", opc, RC>;
  let vc = 1, cx = 1 in defm OT : VSTtgm<opcStr#".ot", opc, RC>;
  let vc = 0, cx = 1 in defm NCOT : VSTtgm<opcStr#".nc.ot", opc, RC>;
}

// Section 8.9.7 - VST (Vector Store)
defm VST : VSTm<"vst", 0x91, V64>;

// Section 8.9.8 - VST (Vector Store Upper)
defm VSTU : VSTm<"vstu", 0x92, V64>;

// Section 8.9.9 - VSTL (Vector Store Lower)
defm VSTL : VSTm<"vstl", 0x93, V64>;

// Section 8.9.10 - VST2D (Vector Store 2D)
defm VST2D : VSTm<"vst2d", 0xd1, V64>;

// Section 8.9.11 - VSTU2D (Vector Store Upper 2D)
defm VSTU2D : VSTm<"vstu2d", 0xd2, V64>;

// Section 8.9.12 - VSTL2D (Vector Store Lower 2D)
defm VSTL2D : VSTm<"vstl2d", 0xd3, V64>;

// Multiclass for VGT instructions
let mayLoad = 1, hasSideEffects = 0, Uses = [VL] in
multiclass VGTbm<string opcStr, string argStr, bits<8>opc, RegisterClass RC,
                 dag dag_in, string disEnc = ""> {
  let DisableEncoding = disEnc in
  def "" : RVM<opc, (outs RC:$vx), dag_in,
               !strconcat(opcStr, " $vx, ", argStr)>;
  let Constraints = "$vx = $base", DisableEncoding = disEnc#"$base",
      isCodeGenOnly = 1 in
  def _v : RVM<opc, (outs RC:$vx), !con(dag_in, (ins RC:$base)),
               !strconcat(opcStr, " $vx, ", argStr)>;
}
multiclass VGTlm<string opcStr, string argStr, bits<8>opc, RegisterClass RC,
                 dag dag_in> {
  defm "" : VGTbm<opcStr, argStr, opc, RC, dag_in>;
  let isCodeGenOnly = 1, VE_VLInUse = 1 in {
    defm l : VGTbm<opcStr, argStr, opc, RC, !con(dag_in, (ins I32:$vl)),
                   "$vl,">;
    defm L : VGTbm<opcStr, argStr, opc, RC, !con(dag_in, (ins VLS:$vl)),
                   "$vl,">;
  }
}
multiclass VGTmm<string opcStr, string argStr, bits<8>opc, RegisterClass RC,
                 dag dag_in> {
  defm "" : VGTlm<opcStr, argStr, opc, RC, dag_in>;
  let m = ?, VE_VLWithMask = 1 in
  defm m : VGTlm<opcStr, argStr#", $m", opc, RC, !con(dag_in, (ins VM:$m))>;
}
let VE_VLIndex = 4 in
multiclass VGTlhm<string opcStr, string argStr, bits<8>opc, RegisterClass RC,
                  dag dag_in> {
  defm rr : VGTmm<opcStr, argStr#", $sy, $sz", opc, RC,
                  !con(dag_in, (ins I64:$sy, I64:$sz))>;
  let cy = 0 in
  defm ir : VGTmm<opcStr, argStr#", $sy, $sz", opc, RC,
                  !con(dag_in, (ins simm7:$sy, I64:$sz))>;
  let cz = 0 in
  defm rz : VGTmm<opcStr, argStr#", $sy, $sz", opc, RC,
                  !con(dag_in, (ins I64:$sy, zero:$sz))>;
  let cy = 0, cz = 0 in
  defm iz : VGTmm<opcStr, argStr#", $sy, $sz", opc, RC,
                  !con(dag_in, (ins simm7:$sy, zero:$sz))>;
}
multiclass VGTtgm<string opcStr, bits<8>opc, RegisterClass RC> {
  let vy = ? in defm v : VGTlhm<opcStr, "$vy", opc, RC, (ins V64:$vy)>;
  let cs = 1, sw = ? in defm s : VGTlhm<opcStr, "$sw", opc, RC, (ins I64:$sw)>;
}
multiclass VGTm<string opcStr, bits<8>opc, RegisterClass RC> {
  let vc = 1 in defm "" : VGTtgm<opcStr, opc, RC>;
  let vc = 0 in defm NC : VGTtgm<opcStr#".nc", opc, RC>;
}

// Section 8.9.13 - VGT (Vector Gather)
defm VGT : VGTm<"vgt", 0xa1, V64>;

// Section 8.9.14 - VGTU (Vector Gather Upper)
defm VGTU : VGTm<"vgtu", 0xa2, V64>;

// Section 8.9.15 - VGTL (Vector Gather Lower)
defm VGTLSX : VGTm<"vgtl.sx", 0xa3, V64>;
let cx = 1 in defm VGTLZX : VGTm<"vgtl.zx", 0xa3, V64>;
def : MnemonicAlias<"vgtl", "vgtl.zx">;
def : MnemonicAlias<"vgtl.nc", "vgtl.zx.nc">;

// Multiclass for VSC instructions
let mayStore = 1, hasSideEffects = 0, Uses = [VL] in
multiclass VSCbm<string opcStr, string argStr, bits<8>opc, dag dag_in> {
  def "" : RVM<opc, (outs), dag_in, !strconcat(opcStr, argStr)>;
  let DisableEncoding = "$vl", isCodeGenOnly = 1, VE_VLInUse = 1 in {
    def l : RVM<opc, (outs), !con(dag_in, (ins I32:$vl)),
                !strconcat(opcStr, argStr)>;
    def L : RVM<opc, (outs), !con(dag_in, (ins VLS:$vl)),
                !strconcat(opcStr, argStr)>;
  }
}
multiclass VSCmm<string opcStr, string argStr, bits<8>opc, dag dag_in> {
  defm "" : VSCbm<opcStr, argStr, opc, dag_in>;
  let m = ?, VE_VLWithMask = 1 in
  defm m : VSCbm<opcStr, argStr#", $m", opc, !con(dag_in, (ins VM:$m))>;
}
let VE_VLIndex = 4 in
multiclass VSClhm<string opcStr, string argStr, bits<8>opc, RegisterClass RC,
                  dag dag_in> {
  defm rrv : VSCmm<opcStr, " $vx, "#argStr#", $sy, $sz", opc,
                   !con(dag_in, (ins I64:$sy, I64:$sz, RC:$vx))>;
  let cy = 0 in
  defm irv : VSCmm<opcStr, " $vx, "#argStr#", $sy, $sz", opc,
                   !con(dag_in, (ins simm7:$sy, I64:$sz, RC:$vx))>;
  let cz = 0 in
  defm rzv : VSCmm<opcStr, " $vx, "#argStr#", $sy, $sz", opc,
                   !con(dag_in, (ins I64:$sy, zero:$sz, RC:$vx))>;
  let cy = 0, cz = 0 in
  defm izv : VSCmm<opcStr, " $vx, "#argStr#", $sy, $sz", opc,
                   !con(dag_in, (ins simm7:$sy, zero:$sz, RC:$vx))>;
}
multiclass VSCtgm<string opcStr, bits<8>opc, RegisterClass RC> {
  let vy = ? in defm v : VSClhm<opcStr, "$vy", opc, RC, (ins V64:$vy)>;
  let cs = 1, sw = ? in defm s : VSClhm<opcStr, "$sw", opc, RC, (ins I64:$sw)>;
}
multiclass VSCm<string opcStr, bits<8>opc, RegisterClass RC> {
  let vc = 1, cx = 0 in defm "" : VSCtgm<opcStr, opc, RC>;
  let vc = 0, cx = 0 in defm NC : VSCtgm<opcStr#".nc", opc, RC>;
  let vc = 1, cx = 1 in defm OT : VSCtgm<opcStr#".ot", opc, RC>;
  let vc = 0, cx = 1 in defm NCOT : VSCtgm<opcStr#".nc.ot", opc, RC>;
}

// Section 8.9.16 - VSC (Vector Scatter)
defm VSC : VSCm<"vsc", 0xb1, V64>;

// Section 8.9.17 - VSCU (Vector Scatter Upper)
defm VSCU : VSCm<"vscu", 0xb2, V64>;

// Section 8.9.18 - VSCL (Vector Scatter Lower)
defm VSCL : VSCm<"vscl", 0xb3, V64>;

// Section 8.9.19 - PFCHV (Prefetch Vector)
let Uses = [VL] in
multiclass PFCHVbm<string opcStr, string argStr, bits<8>opc, dag dag_in> {
  def "" : RVM<opc, (outs), dag_in, !strconcat(opcStr, argStr)>;
  let DisableEncoding = "$vl", isCodeGenOnly = 1, VE_VLInUse = 1 in {
    def l : RVM<opc, (outs), !con(dag_in, (ins I32:$vl)),
                !strconcat(opcStr, argStr)>;
    def L : RVM<opc, (outs), !con(dag_in, (ins VLS:$vl)),
                !strconcat(opcStr, argStr)>;
  }
}
let VE_VLIndex = 2 in
multiclass PFCHVm<string opcStr, bits<8>opc> {
  defm rr : PFCHVbm<opcStr, " $sy, $sz", opc, (ins I64:$sy, I64:$sz)>;
  let cy = 0 in
  defm ir : PFCHVbm<opcStr, " $sy, $sz", opc, (ins simm7:$sy, I64:$sz)>;
  let cz = 0 in
  defm rz : PFCHVbm<opcStr, " $sy, $sz", opc, (ins I64:$sy, zero:$sz)>;
  let cy = 0, cz = 0 in
  defm iz : PFCHVbm<opcStr, " $sy, $sz", opc, (ins simm7:$sy, zero:$sz)>;
}
let vc = 1, vx = 0 in defm PFCHV : PFCHVm<"pfchv", 0x80>;
let vc = 0, vx = 0 in defm PFCHVNC : PFCHVm<"pfchv.nc", 0x80>;
