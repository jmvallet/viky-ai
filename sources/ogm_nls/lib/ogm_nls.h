/*
 *  Internal header for Natural Language Server library
 *  Copyright (c) 2017 Pertimm by Patrick Constant
 *  Dev: August 2017
 *  Version 1.0
 */
#include <lognls.h>
#include <logaddr.h>
#include <loguci.h>
#include <logpath.h>
#include <logthr.h>
#include <logheap.h>
#include <logxml.h>
#include <yajl/yajl_gen.h>
#include <yajl/yajl_parse.h>
#include <yajl/yajl_tree.h>
#include <string.h>

typedef struct og_listening_thread og_listening_thread;

#define DOgNlsPortNumber  9345

struct timeout_conf_context
{
  char *timeout_name; /** name of the timeout : answer_timeout, socket_read_timeout...*/
  int old_timeout; /** timeout from previous conf */
  int default_timeout; /** default timeout value */
};

struct og_nls_conf
{
  int max_listening_threads;
  int max_parallel_threads;
  char data_directory[DPcPathSize];
  int permanent_threads;

  int max_request_size;

  /** Global timeout determining socket_read_timeout and request_processing_timeout*/
  int answer_timeout;

  /** backlog timeout. If only answer_timeout is specified, backlog_timeout is 10 % of answer_timeout*/
  int backlog_timeout;

  /** socket timeout. If only answer_timeout is specified, socket_read_timeout is 10 % of answer_timeout*/
  int socket_read_timeout;

  /** Timeout for the request. If only answer_timeout is specified, request_processing_timeout is 80 % of answer_timeout*/
  int request_processing_timeout;

  /** backlog timeout specified only for indexing requests. If not specified, it has the same value as backlog_timeout*/
  int backlog_indexing_timeout;
  int backlog_max_pending_requests;
  int loop_answer_timeout;

};

struct json_object
{
  yajl_gen yajl_gen;

  og_bool error_detected;

  /**  Yajl Json json buffer **/
  og_heap hb_json_buffer;

};

/** data structure for a listening thread **/
struct og_listening_thread
{

  /** Error handler */
  void *herr;

  /** Message handler */
  void *hmsg;

  ogmutex_t *hmutex;
  struct og_ctrl_nls *ctrl_nls;
  struct og_loginfo loginfo[1];
  int ID, running, looping, disabled, state;
  int request_running, request_running_start, request_running_time;
  ogthread_t IT;
  unsigned hsocket_in;
  int connection_closed;
  struct sockaddr_in socket_in;

  int content_start, content_length;

  struct og_ucisr_output output[1];
  int valid_request;

  void *hucis;

  /** for permanent lt threads **/
  ogsem_t csem, *hsem;
  int must_stop;

  ogint64_t t0, t1, t2, t3, ot3;

  struct json_object json[1];

};

struct og_ctrl_nls
{
  void *herr, *hmsg;
  ogmutex_t *hmutex;
  struct og_loginfo loginfo[1];
  char WorkingDirectory[DPcPathSize];
  char configuration_file[DPcPathSize];
  int icwd;
  unsigned char cwd[DPcPathSize];
  struct og_nls_conf conf[1];

  struct og_ucisr_output output[1];
  struct og_ucisw_input winput[1];
  struct og_ucisr_input input[1];

  char sremote_addr[DPcPathSize];
  int must_stop;

  void *haddr, *hucis;
  struct og_conf_lines nls_addresses;
  char hostname[DPcPathSize];
  int port_number;

  struct og_listening_thread *Lt;
  int LtNumber;

  ogsem_t hsem_run3[1];
  /** Mutex to choose current lt */
  ogmutex_t hmutex_run_lt[1];

};

struct jsonValuesContext
{
  char mapKey[DPcPathSize];
  char stringValue[DPcPathSize];
  int intValue;
  double doubleValue;
  int booleanValue;
  struct og_listening_thread *lt;
};

/** nlsrun.c **/
int NlsRunSendErrorStatus(void *ptr, struct og_socket_info *info, int error_status, og_string message);
int NlsWaitForListeningThreads(char *label, struct og_ctrl_nls *ctrl_nls);

/** nlsltp.c Permanent threads **/
int OgPermanentLtThread(void *ptr);
int NlsInitPermanentLtThreads(struct og_ctrl_nls *ctrl_nls);
int NlsStopPermanentLtThreads(struct og_ctrl_nls *ctrl_nls);
int NlsFlushPermanentLtThreads(struct og_ctrl_nls *ctrl_nls);

/** nlslt.c **/
int OgListeningThread(void *ptr);

/** nlslog.c **/
int NlsRequestLog(struct og_listening_thread *lt, og_string function_name, og_string label, int additional_log_flags);
int NlsThrowError(struct og_listening_thread *lt, og_string format, ...);

/** nlsler.c **/
int OgListeningThreadError(struct og_listening_thread *lt);

/** nlsconf.c **/
int NlsReadConfigurationFile(struct og_ctrl_nls *ctrl_nls, int init);

/** nlsltu.c **/
og_bool OgListeningThreadAnswerUci(struct og_listening_thread *lt);

/** nlsonem.c **/
int NlsOnEmergency(struct og_ctrl_nls *ctrl_nls);

/** lns_json **/
og_status OgNLSJsonInit(struct og_listening_thread *lt);
og_status OgNLSJsonReset(struct og_listening_thread *lt);
og_status OgNLSJsonFlush(struct og_listening_thread *lt);
og_status OgNLSJsonGenInteger(struct og_listening_thread *lt, long long int number);
og_status OgNLSJsonGenDouble(struct og_listening_thread *lt, double number);
og_status OgNLSJsonGenNumber(struct og_listening_thread *lt, og_string number, int len);
og_status OgNLSJsonGenBool(struct og_listening_thread *lt, og_bool boolean);
og_status OgNLSJsonGenString(struct og_listening_thread *lt, og_string string);
og_status OgNLSJsonGenStringSized(struct og_listening_thread *lt, og_string string, int length);
og_status OgNLSJsonGenKeyValueString(struct og_listening_thread *lt, og_string key, og_string value_string);
og_status OgNLSJsonGenKeyValueStringSized(struct og_listening_thread *lt, og_string key, og_string value_string,
    int length);
og_status OgNLSJsonGenKeyValueInteger(struct og_listening_thread *lt, og_string key, int number);
og_status OgNLSJsonGenKeyValueDouble(struct og_listening_thread *lt, og_string key, double number);
og_status OgNLSJsonGenNull(struct og_listening_thread *lt);
og_status OgNLSJsonGenArrayOpen(struct og_listening_thread *lt);
og_status OgNLSJsonGenArrayClose(struct og_listening_thread *lt);
og_status OgNLSJsonGenMapOpen(struct og_listening_thread *lt);
og_status OgNLSJsonGenMapClose(struct og_listening_thread *lt);
og_status OgNLSJsonReFormat(struct og_listening_thread *lt, og_string json, size_t json_size);
og_status OgNLSJsonAnswer(struct og_listening_thread *lt, og_string json, size_t json_size);

int get_null(void * ctx);
int get_boolean(void * ctx, int boolean);
int get_integer(void * ctx, long long integerVal);
int get_double(void * ctx, double doubleVal);
int get_number(void * ctx, const char * numberVal, size_t l);
int get_string(void * ctx, const unsigned char * stringVal, size_t stringLen);
int get_map_key(void * ctx, const unsigned char * stringVal, size_t stringLen);
int get_start_map(void * ctx);
int get_end_map(void * ctx);
int get_start_array(void * ctx);
int get_end_array(void * ctx);
