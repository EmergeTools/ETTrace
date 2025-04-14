//
//  dydl_libs.c
//  ETTrace
//
//  Created by Noah Martin on 2/26/25.
//

#import <mach/task_info.h>
#import <mach/task.h>
#import <mach/mach_vm.h>
#import <stdio.h>
#import <mach-o/dyld_images.h>
#import <mach-o/loader.h>
#import "macho.h"
#import "dyld_libs.h"

int getDyldInfo(task_name_t remoteTask, struct task_dyld_info *dyldInfo) {
  kern_return_t kr = 0;
  mach_msg_type_number_t outCnt = TASK_DYLD_INFO_COUNT;
  kr = task_info(remoteTask, TASK_DYLD_INFO, (task_info_t) dyldInfo, &outCnt);
  if (kr != KERN_SUCCESS) {
    fprintf(stderr, "Unable to call task_info");
    return -1;
  }
  return 0;
}

int getSymbolInfo(task_name_t remoteTask, struct symbol_info *si) {
  
  struct task_dyld_info dyldInfo;
  if (getDyldInfo(remoteTask, &dyldInfo)) {
    return -1;
  }
  
  struct dyld_all_image_infos *data;
  mach_msg_type_number_t dataCnt;
  mach_vm_read(remoteTask, dyldInfo.all_image_info_addr, sizeof(struct dyld_all_image_infos), (vm_offset_t *) &data, &dataCnt);
  
  long dlOpenAddr = 0;
  long pThreadCreateAddr = 0;
  
  struct dyld_image_info *dyldInfoArray;
  mach_msg_type_number_t dataSize;
  mach_vm_read(remoteTask, data->infoArray, sizeof(struct dyld_image_info) * data->infoArrayCount, (vm_offset_t *) &dyldInfoArray, &dataSize);
  bool err = false;
  for (int i = 0; i < data->infoArrayCount; i++) {
    const char *path;
    mach_msg_type_number_t size;
    mach_vm_read(remoteTask, dyldInfoArray[i].imageFilePath, PATH_MAX, (vm_offset_t *) &path, &size);
    if (strstr(path, "libdyld.dylib")) {
      long offset = find_symbol_offset(path, "_dlopen");
      if (offset > 0) {
        si->dlOpenAddr = ((long) dyldInfoArray[i].imageLoadAddress) + offset;
        printf("addr 0x%lX\n", si->dlOpenAddr);
      } else {
        err = true;
      }
    } else if (strstr(path, "libsystem_pthread.dylib")) {
      long offset = find_symbol_offset(path, "_pthread_create_from_mach_thread");
      if (offset > 0) {
        si->pThreadCreateAddr = ((long) dyldInfoArray[i].imageLoadAddress) + offset;
      } else {
        err = true;
      }
    }
    vm_deallocate(mach_task_self(), path, size);
  }
  
  vm_deallocate(mach_task_self(), data, dataCnt);
  vm_deallocate(mach_task_self(), dyldInfoArray, dataSize);

  return err ? -1 : 0;
}
