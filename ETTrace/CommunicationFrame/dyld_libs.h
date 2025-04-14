//
//  dyld_libs.h
//  ETTrace
//
//  Created by Noah Martin on 2/26/25.
//

struct symbol_info {
  long dlOpenAddr;
  long pThreadCreateAddr;
};

int getSymbolInfo(task_name_t remoteTask, struct symbol_info *si);
