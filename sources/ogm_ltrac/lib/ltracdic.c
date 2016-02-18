/*
 *  Main function for Linguistic Transformation compile library
 *  Copyright (c) 2009 Pertimm, Inc. by Patrick Constant
 *  Dev : November 2009
 *  Version 1.0
*/
#include "ogm_ltrac.h"



int FilterDict(struct og_ctrl_ltrac *);



int LtracDicAdd(struct og_ctrl_ltrac *ctrl_ltrac,struct ltrac_dic_input *dic_input)
{
struct og_ltrac_input *input = ctrl_ltrac->input;
unsigned char out[DPcAutMaxBufferSize+9];
oindex states[DPcAutMaxBufferSize+9];
char string[2*DPcPathSize];
char buffer[DPcPathSize];
int nstate0,nstate1,iout;
int ibuffer,retour;
int length;

if (ctrl_ltrac->ha_filter) {
  memcpy(string,dic_input->value,dic_input->value_length);
  string[dic_input->value_length]=0;
  string[dic_input->value_length+1]='|';
  length=dic_input->value_length+2;
  if (ctrl_ltrac->ha_seen) {
    IFE(OgAutAdd(ctrl_ltrac->ha_seen,length,string));
    }
  }

if (dic_input->frequency < input->min_frequency) DONE;

if (ctrl_ltrac->ha_filter) {
  if (ctrl_ltrac->loginfo->trace & DOgLtracTraceAdd) {
    IFE(OgUniToCp(length,string,DPcPathSize,&ibuffer,buffer,DOgCodePageUTF8,0,0));
    OgMsg(ctrl_ltrac->hmsg,"",DOgMsgDestInLog,"LtracDicAdd: looking for %s", buffer);
    }

  IFE(retour=OgAutScanf(ctrl_ltrac->ha_filter,length,string,&iout,out,&nstate0,&nstate1,states));
  if (!retour) DONE;
  }

if (ctrl_ltrac->loginfo->trace & DOgLtracTraceAdd) {
  char attribute_string[DPcPathSize];
  IFE(ctrl_ltrac->OgSidxAttributeNumberToString(ctrl_ltrac->hsidx,dic_input->attribute_number,attribute_string));
  IFE(OgUniToCp(dic_input->value_length,dic_input->value,DPcPathSize,&ibuffer,buffer,DOgCodePageUTF8,0,0));
  OgMsg(ctrl_ltrac->hmsg,"",DOgMsgDestInLog
    , "LtracAttributesAdd: adding %d=%s '%s' with frequency %d"
    ,dic_input->attribute_number,attribute_string,buffer,dic_input->frequency);
  }

if (input->dictionaries_to_export & DOgLtracDictionaryTypeBase) {
  /* word | attribute_number language_code frequency **/
  IFE(LtracDicBaseAdd(ctrl_ltrac,dic_input));
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypeSwap) {
  if (dic_input->frequency < input->min_frequency_swap) DONE;
  /* word_less_1_letter | attribute_number language_code position frequency word */
  IFE(LtracDicSwapAdd(ctrl_ltrac,dic_input));
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypePhon) {
  /* phonetic_form | attribute_number language_code frequency **/
  IFE(LtracDicPhonAdd(ctrl_ltrac,dic_input));
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypeAspell) {
  /** One word per line in a flat file **/
  IFE(LtracDicAspellAdd(ctrl_ltrac,dic_input));
  }


DONE;
}




int LtracDicAddFilterWords(struct og_ctrl_ltrac *ctrl_ltrac)
{
struct ltrac_dic_input cdic_input, *dic_input=&cdic_input;
struct og_ltrac_input *input = ctrl_ltrac->input;
unsigned char out1[DPcAutMaxBufferSize+9];
unsigned char out2[DPcAutMaxBufferSize+9];
int retour1,nstate0_1,nstate1_1,iout1;
int retour2,nstate0_2,nstate1_2,iout2;
oindex states1[DPcAutMaxBufferSize+9];
oindex states2[DPcAutMaxBufferSize+9];

// Add words remaining in automaton unseen with attribute number 1 and frequency 1
dic_input->attribute_number=1;
dic_input->language_code=0;
dic_input->frequency=1;

if ((retour1=OgAutScanf(ctrl_ltrac->ha_filter,-1,"",&iout1,out1,&nstate0_1,&nstate1_1,states1))) {
  do {
    IFE(retour1);

    IFE(retour2 = OgAutScanf(ctrl_ltrac->ha_seen,iout1,out1,&iout2,out2,&nstate0_2,&nstate1_2,states2));
    if(retour2){ continue;}

    // remove terminating character
    dic_input->value_length = iout1-2;
    dic_input->value = out1;

    if (input->dictionaries_to_export & DOgLtracDictionaryTypeBase) {
      /* word | attribute_number language_code frequency **/
      IFE(LtracDicBaseAdd(ctrl_ltrac,dic_input));
      }
    if (input->dictionaries_to_export & DOgLtracDictionaryTypeSwap) {
      /* word_less_1_letter | attribute_number language_code position frequency word */
      IFE(LtracDicSwapAdd(ctrl_ltrac,dic_input));
      }
    if (input->dictionaries_to_export & DOgLtracDictionaryTypePhon) {
      /* phonetic_form | attribute_number language_code frequency **/
      IFE(LtracDicPhonAdd(ctrl_ltrac,dic_input));
      }
    if (input->dictionaries_to_export & DOgLtracDictionaryTypeAspell) {
      /** One word per line in a flat file **/
      IFE(LtracDicAspellAdd(ctrl_ltrac,dic_input));
      }
    }
  while((retour1=OgAutScann(ctrl_ltrac->ha_filter,&iout1,out1,nstate0_1,&nstate1_1,states1)));
  }

DONE;
}






int LtracDicInit(struct og_ctrl_ltrac *ctrl_ltrac)
{
struct og_aut_param caut_param,*aut_param=&caut_param;
struct og_pho_param cpho_param,*pho_param=&cpho_param;
struct og_ltrac_input *input = ctrl_ltrac->input;
char erreur[DOgErrorSize];
struct stat filestat;

memset(aut_param,0,sizeof(struct og_aut_param));
aut_param->herr=ctrl_ltrac->herr;
aut_param->hmutex=ctrl_ltrac->hmutex;
aut_param->loginfo.trace = DOgAutTraceMinimal+DOgAutTraceMemory;
aut_param->loginfo.where = ctrl_ltrac->loginfo->where;
aut_param->state_number = 0x1000;

// Initialize and transfer filter dictionary to an automaton
if (input->filter_dict[0]) {
  sprintf(aut_param->name,"ltrac filter");
  IFn(ctrl_ltrac->ha_filter=OgAutInit(aut_param)) DPcErr;

  sprintf(aut_param->name,"ltrac filter seen");
  IFn(ctrl_ltrac->ha_seen=OgAutInit(aut_param)) DPcErr;

  IFx(stat(input->filter_dict,&filestat)) {
    sprintf(erreur,"LtracDicInit: Impossible to stat filter dictionary '%s'", input->filter_dict);
    OgErr(ctrl_ltrac->herr,erreur); DPcErr;
    }
  else{
    IFE(FilterDict(ctrl_ltrac));
    }
  }

if (input->dictionaries_to_export & DOgLtracDictionaryTypeBase) {
  sprintf(aut_param->name,"ltrac base");
  IFn(ctrl_ltrac->ha_base=OgAutInit(aut_param)) DPcErr;
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypeSwap) {
  sprintf(aut_param->name,"ltrac swap");
  IFn(ctrl_ltrac->ha_swap=OgAutInit(aut_param)) DPcErr;
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypePhon) {
  sprintf(aut_param->name,"ltrac phon");
  IFn(ctrl_ltrac->ha_phon=OgAutInit(aut_param)) DPcErr;
  memset(pho_param,0,sizeof(struct og_pho_param));
  pho_param->herr=ctrl_ltrac->herr;
  pho_param->hmsg=ctrl_ltrac->hmsg;
  pho_param->hmutex=ctrl_ltrac->hmutex;
  pho_param->loginfo.trace = DOgPhoTraceMinimal+DOgPhoTraceMemory;
  pho_param->loginfo.where = ctrl_ltrac->loginfo->where;
  if(ctrl_ltrac->WorkingDirectory[0]) sprintf(pho_param->conf,"%s/conf/phonet_ltra_conf.xml",ctrl_ltrac->WorkingDirectory);
  else strcpy(pho_param->conf,"conf/phonet_ltra_conf.xml");
  if (OgFileExists(pho_param->conf)) {
     IFn(ctrl_ltrac->hpho=OgPhoInit(pho_param)) DPcErr;
     }
  else {
    OgMsg(ctrl_ltrac->hmsg,"",DOgMsgDestInLog
      , "LtracDicInit: impossible to open '%s' phonetic dictionary will not be created",pho_param->conf);
    }
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypeAspell) {
  IFn(ctrl_ltrac->fd_aspell=fopen(ctrl_ltrac->name_aspell,"w")) {
    sprintf(erreur,"LtracDicInit: Impossible to open '%s' for writing", ctrl_ltrac->name_aspell);
    OgErr(ctrl_ltrac->herr,erreur); DPcErr;
    }
  }

DONE;
}




int FilterDict(struct og_ctrl_ltrac *ctrl_ltrac)
{
struct og_ltrac_input *input = ctrl_ltrac->input;
unsigned char uni[2*DPcPathSize];
char erreur[DPcPathSize];
char string[DPcPathSize];
FILE *filter_dict;
int iuni;
int len;

IFn(filter_dict=fopen(input->filter_dict,"rb")){
  sprintf(erreur,"FilterDict: Impossible to open '%s'", input->filter_dict);
  OgErr(ctrl_ltrac->herr,erreur); DPcErr;
  }

memset(string,0,DPcPathSize);

while(fgets(string,DPcPathSize,filter_dict)){

  len = strlen(string)-1;
  while(string[len] == '\n' || string[len] == '\r'){
    string[len] = 0;
    len--;
    }
  // Terminating char, to avoid matching substrings
  string[len+1]='|';
  string[len+2]=0;

  IFE(OgCpToUni(strlen(string),string,2*DPcPathSize,&iuni,uni,input->codepage,0,0));
  IFE(OgAutAdd(ctrl_ltrac->ha_filter,iuni,uni));

  if (ctrl_ltrac->loginfo->trace & DOgLtracTraceAdd) {
    OgMsg(ctrl_ltrac->hmsg,"",DOgMsgDestInLog,"FilterDict: added %s", string);
    }
  }

fclose(filter_dict);

DONE;
}





int LtracDicWrite(struct og_ctrl_ltrac *ctrl_ltrac)
{
struct og_ltrac_input *input = ctrl_ltrac->input;
if (input->dictionaries_to_export & DOgLtracDictionaryTypeBase) {
  if (input->dictionaries_minimization & DOgLtracDictionaryTypeBase) {
    IFE(OgAum(ctrl_ltrac->ha_base));
    }
  IFE(OgAuf(ctrl_ltrac->ha_base,0));
  IFE(OgAufWrite(ctrl_ltrac->ha_base,ctrl_ltrac->name_base));
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypeSwap) {
  if (input->dictionaries_minimization & DOgLtracDictionaryTypeSwap) {
    IFE(OgAum(ctrl_ltrac->ha_swap));
    }
  IFE(OgAuf(ctrl_ltrac->ha_swap,0));
  IFE(OgAufWrite(ctrl_ltrac->ha_swap,ctrl_ltrac->name_swap));
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypePhon) {
  if (input->dictionaries_minimization & DOgLtracDictionaryTypePhon) {
    IFE(OgAum(ctrl_ltrac->ha_phon));
    }
  IFE(OgAuf(ctrl_ltrac->ha_phon,0));
  IFE(OgAufWrite(ctrl_ltrac->ha_phon,ctrl_ltrac->name_phon));
  IFE(OgPhoFlush(ctrl_ltrac->hpho));
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypeAspell) {
  fflush(ctrl_ltrac->fd_aspell);
  }
DONE;
}





int LtracDicFlush(struct og_ctrl_ltrac *ctrl_ltrac)
{
struct og_ltrac_input *input = ctrl_ltrac->input;

if(input->filter_dict[0]){
  IFE(OgAutFlush(ctrl_ltrac->ha_filter));
  IFE(OgAutFlush(ctrl_ltrac->ha_seen));
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypeBase) {
  IFE(OgAutFlush(ctrl_ltrac->ha_base));
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypeSwap) {
  IFE(OgAutFlush(ctrl_ltrac->ha_swap));
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypePhon) {
  IFE(OgAutFlush(ctrl_ltrac->ha_phon));
  }
if (input->dictionaries_to_export & DOgLtracDictionaryTypeAspell) {
  fclose(ctrl_ltrac->fd_aspell);
  }
DONE;
}




