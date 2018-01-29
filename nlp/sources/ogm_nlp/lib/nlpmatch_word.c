/*
 *  Handling log messages for Natural Language Processing library
 *  Copyright (c) 2017 Pertimm, by Patrick Constant
 *  Dev : September 2017
 *  Version 1.0
 */
#include "ogm_nlp.h"
#include <stdlib.h>

static og_status NlpMatchWord(og_nlp_th ctrl_nlp_th, int Irequest_word);
static og_status NlpMatchWordInPackage(og_nlp_th ctrl_nlp_th, struct request_word *request_word, int input_length,
    unsigned char *input, struct interpret_package *interpret_package);

og_status NlpMatchWords(og_nlp_th ctrl_nlp_th)
{
  int request_word_used = OgHeapGetCellsUsed(ctrl_nlp_th->hrequest_word);
  for (int i = 0; i < request_word_used; i++)
  {
    IFE(NlpMatchWord(ctrl_nlp_th, i));
  }
  DONE;
}

static og_status NlpMatchWord(og_nlp_th ctrl_nlp_th, int Irequest_word)
{
  struct request_word *request_word = OgHeapGetCell(ctrl_nlp_th->hrequest_word, Irequest_word);
  IFN(request_word) DPcErr;

  og_string string_request_word = OgHeapGetCell(ctrl_nlp_th->hba, request_word->start);
  IFN(string_request_word) DPcErr;

  unsigned char input[DPcAutMaxBufferSize + 9];
  int input_length = request_word->length;
  memcpy(input, string_request_word, input_length);
  input[input_length++] = '\1';
  input[input_length] = 0;

  char digit[DPcPathSize];
  digit[0] = 0;
  if (request_word->is_digit)
  {
    snprintf(digit, DPcPathSize, " -> %f", request_word->digit_value);
  }

  NlpLog(DOgNlpTraceMatch, "Looking for input parts for string '%s'%s:", string_request_word, digit);

  int interpret_package_used = OgHeapGetCellsUsed(ctrl_nlp_th->hinterpret_package);
  for (int i = 0; i < interpret_package_used; i++)
  {
    struct interpret_package *interpret_package = OgHeapGetCell(ctrl_nlp_th->hinterpret_package, i);
    IFN(interpret_package) DPcErr;
    IFE(NlpMatchWordInPackage(ctrl_nlp_th, request_word, input_length, input, interpret_package));
  }

  DONE;
}

static og_status NlpMatchWordInPackage(og_nlp_th ctrl_nlp_th, struct request_word *request_word, int input_length,
    unsigned char *input, struct interpret_package *interpret_package)
{
  package_t package = interpret_package->package;

  if (request_word->is_digit)
  {
    struct digit_input_part *digit_input_part_all = OgHeapGetCell(package->hdigit_input_part, 0);
    int digit_input_part_used = OgHeapGetCellsUsed(package->hdigit_input_part);
    for (int i = 0; i < digit_input_part_used; i++)
    {
      struct digit_input_part *digit_input_part = digit_input_part_all + i;
      // There is not need to have a special input part here for digit words
      IFE(NlpRequestInputPartAddWord(ctrl_nlp_th, request_word, interpret_package, digit_input_part->Iinput_part,TRUE));
    }
  }

  unsigned char out[DPcAutMaxBufferSize + 9];
  oindex states[DPcAutMaxBufferSize + 9];
  int retour, nstate0, nstate1, iout;

  if ((retour = OgAufScanf(package->ha_word, input_length, input, &iout, out, &nstate0, &nstate1, states)))
  {
    do
    {
      IFE(retour);
      int Iinput_part;
      unsigned char *p = out;
      IFE(DOgPnin4(ctrl_nlp_th->herr,&p,&Iinput_part));
      NlpLog(DOgNlpTraceMatch, "    found input part %d in request package %d", Iinput_part,
          interpret_package->self_index)
      IFE(NlpRequestInputPartAddWord(ctrl_nlp_th, request_word, interpret_package, Iinput_part,FALSE));
    }
    while ((retour = OgAufScann(package->ha_word, &iout, out, nstate0, &nstate1, states)));
  }

  DONE;
}

static og_bool str_remove(og_char_buffer *source, og_string to_replace)
{
  int to_replace_size = strlen(to_replace);
  int source_size = strlen(source);
  og_char_buffer *p = strstr(source, to_replace);
  if (p)
  {
    memmove(p, p + to_replace_size, source_size - to_replace_size - (source - p) + 1);
    IFE(str_remove(source, to_replace));
    return TRUE;
  }
  return FALSE;
}

static og_status getNumberSeparators(og_string locale, og_char_buffer* thousand_sep, og_char_buffer* decimal_sep)
{
  if (strcmp(locale, "fr") == 0)
  {
    snprintf(thousand_sep, 5, " ");
    snprintf(decimal_sep, 5, ",");
  }
  else if (strcmp(locale, "fr-fr") == 0)
  {
    snprintf(thousand_sep, 5, " ");
    snprintf(decimal_sep, 5, ",");
  }
  else if (strcmp(locale, "en") == 0)
  {
    snprintf(thousand_sep, 5, ",");
    snprintf(decimal_sep, 5, ".");
  }
  else if (strcmp(locale, "en-gb") == 0)
  {
    snprintf(thousand_sep, 5, ",");
    snprintf(decimal_sep, 5, ".");
  }
  else if (strcmp(locale, "en-us") == 0)
  {
    snprintf(thousand_sep, 5, ",");
    snprintf(decimal_sep, 5, ".");
  }
  else if (strcmp(locale, "de") == 0)
  {
    snprintf(thousand_sep, 5, " ");
    snprintf(decimal_sep, 5, ",");
  }
  else if (strcmp(locale, "de-ch") == 0)
  {
    snprintf(thousand_sep, 5, "\'");
    snprintf(decimal_sep, 5, ".");
  }
  else if (strcmp(locale, "fr-ch") == 0)
  {
    snprintf(thousand_sep, 5, "\'");
    snprintf(decimal_sep, 5, ".");
  }
  else   // by default it's french! french is great!
  {
    snprintf(thousand_sep, 5, " ");
    snprintf(decimal_sep, 5, ",");
  }
  DONE;
}

static og_bool NlpNumberParsing(og_nlp_th ctrl_nlp_th, og_string sentence, GRegex *regular_expression,
    og_char_buffer *thousand_sep, double *p_value)
{
  if (p_value) *p_value = 0;
  // run the regular expression
  GMatchInfo *match_info = NULL;
  og_bool match = g_regex_match(regular_expression, sentence, 0, &match_info);
  if (!match) return FALSE;

  // getting the integer part
  gchar *integerpart = g_match_info_fetch(match_info, 1);

  // removing thousand separators
  og_char_buffer value_buffer[DPcPathSize];
  snprintf(value_buffer, DPcPathSize, "%s", integerpart);

  str_remove(value_buffer, thousand_sep);

  gchar *decimalpart = g_match_info_fetch(match_info, 2);
  if (decimalpart)
  {
    snprintf(value_buffer + strlen(value_buffer), DPcPathSize, ".%s", decimalpart);
  }
  double tmp_value = atof(value_buffer);

  // some cleaning
  g_free(integerpart);
  g_free(decimalpart);
  g_match_info_free(match_info);

  *p_value = tmp_value;

  return TRUE;
}

//static og_status NlpMergeWords(og_nlp_th ctrl_nlp_th, struct request_word *request_word_start, struct request_word *request_word_end)
//{
//  DONE;
//}

og_bool NlpGroupDigits(og_nlp_th ctrl_nlp_th)
{
  // getting the locale
  // ctrl_nlp_th->
  // not yet, let's consider it's french
  og_string locale = "fr";

  // getting thousand and decimal separator
  og_char_buffer thousand_sep[5];
  og_char_buffer decimal_sep[5];
  getNumberSeparators(locale, thousand_sep, decimal_sep);

  og_string request_sentence = ctrl_nlp_th->request_sentence;

  // parsing the numbers
  double value = 0;
  int request_word_used = OgHeapGetCellsUsed(ctrl_nlp_th->hrequest_word);

  struct request_word *request_word_start;
  struct request_word *request_word_end;
  struct request_word *last_request_match_word = NULL;

  char pattern[DPcPathSize];
  snprintf(pattern, DPcPathSize, "^((?:(?:\\d{1,3}(?:%s\\d{3})+)|\\d+))(?:%s(\\d*))?$", thousand_sep, decimal_sep);

  GError *regexp_error = NULL;
  GRegex *regular_expression = g_regex_new(pattern, 0, 0, &regexp_error);

  if (request_word_used > 0)
  {
    request_word_start = OgHeapGetCell(ctrl_nlp_th->hrequest_word, 0);
    request_word_start->is_merged = FALSE;
    IFN(request_word_start) DPcErr;
  }

  og_bool previous_match = FALSE;
  for (int i = 0; i < request_word_used; i++)
  {
    request_word_end = OgHeapGetCell(ctrl_nlp_th->hrequest_word, i);
    IFN(request_word_end) DPcErr;

    og_string string_request_word = OgHeapGetCell(ctrl_nlp_th->hba, request_word_end->start);
    IFN(string_request_word) DPcErr;

//    int j = 0;
//    do
//    {
//      if ((string_request_word[j] != thousand_sep) && (string_request_word[j] != decimal_sep)
//          && (!OgUniIsdigit(string_request_word[j]))) return FALSE;
//      j++;
//    }
//    while (string_request_word[j] != '\0');

    // on ne prend pas en compte les séparateurs en fin de nombre
    if (!strcmp(string_request_word, thousand_sep) || !strcmp(string_request_word, decimal_sep))
    {
      continue;
    }

    // recuperer la string entre DigitGroupStart et DigitGroupEnd
    og_char_buffer expression_string[DPcPathSize];
    int start_position = request_word_start->start_position;
    int end_position = request_word_end->start_position + request_word_end->length_position;
    int length = end_position - start_position;
    snprintf(expression_string, DPcPathSize, "%.*s", length, request_sentence + start_position);

    og_bool number_match = NlpNumberParsing(ctrl_nlp_th, expression_string, regular_expression, thousand_sep, &value);
    IFE(number_match);

    if (number_match)
    {
      if(previous_match)
      {
        request_word_end->is_merged = TRUE;
      }
      previous_match = TRUE;
      last_request_match_word = request_word_end;
    }
    else
    {
      if(previous_match)
      {
        // grouper les mots
        request_word_start->length_position = last_request_match_word->start_position - request_word_start->start_position + last_request_match_word->length_position;
      }

      previous_match = FALSE;

      if (i + 1 < request_word_used)
      {
        // decaler le point de depart de la combinaison analysée
        request_word_start = OgHeapGetCell(ctrl_nlp_th->hrequest_word, i + 1);
        request_word_start->is_digit = TRUE;
        request_word_start->digit_value = value;
      }

    }

    if(previous_match)
    {
      // grouper les mots et stocker la valeur
      request_word_start->length_position = last_request_match_word->start_position - request_word_start->start_position + last_request_match_word->length_position;
      request_word_start->is_digit = TRUE;
      request_word_start->digit_value = value;
    }


  }
  g_regex_unref(regular_expression);
  DONE;
}

