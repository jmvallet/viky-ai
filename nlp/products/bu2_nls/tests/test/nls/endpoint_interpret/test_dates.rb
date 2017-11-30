# encoding: utf-8

require 'test_helper'

module Nls

  module EndpointInterpret

    class TestDates < NlsTestCommon

      def set_now(date)
        @now = DateTime(date)
      end

      def setup
        super

        Nls.remove_all_packages

        Interpretation.default_locale = "en-GB"

        Nls.package_update(fixture_parse("package_number_digits.json"))
        Nls.package_update(fixture_parse("package_number_letters.json"))
        Nls.package_update(fixture_parse("package_number.json"))
        Nls.package_update(fixture_parse("package_date.json"))
        Nls.package_update(fixture_parse("package_complex_date.json"))
        Nls.package_update(fixture_parse("package_special_dates.json"))
      end

      def test_simple_date
        expected = "2017-12-03T00:00:00Z"
        check_interpret("3 décembre 2017", interpretation: "date_day_month_year", solution: { date: expected } )
        check_interpret("december the third, two thousand and seventeen", interpretation: "date_day_month_year", solution: { date: expected } )
        check_interpret("december the third, 2017", interpretation: "date_day_month_year", solution: { date: expected } )
        check_interpret("december the 3 rd, 2017", interpretation: "date_day_month_year", solution: { date: expected } )
        check_interpret("trois decembre deux mille dix sept", interpretation: "date_day_month_year", solution: { date: expected } )
        check_interpret("3/12/2017", interpretation: "date_day_month_year", solution: { date: expected } )
      end

      def test_on_date
        expected = "2017-12-03T00:00:00Z"
        check_interpret("le 3 décembre 2017", interpretation: "single_date", solution: {date: expected})
        check_interpret("on december the third, 2017", interpretation: "single_date", solution: {date: expected})
        check_interpret("on 03/12/2017", interpretation: "single_date", solution: {date: expected})
        check_interpret("le 03/12/2017", interpretation: "single_date", solution: {date: expected})
      end

      def test_interval_date
        solution = {
          "date_begin" => "2017-12-03T00:00:00Z",
          "date_end" => "2018-01-15T00:00:00Z"
        }
        check_interpret("du 3 decembre 2017 au 15 janvier 2018", interpretation: "date_interval", solution: solution )
        check_interpret("from december the 3 rd, 2017 to january the 15 th, 2018", interpretation: "date_interval", solution: solution )
        sentence = "du trois decembre deux mille dix sept au quinze janvier deux mille dix huit"
        check_interpret(sentence, interpretation: "date_interval", solution: solution )
        sentence = "from december the third, two thousand and seventeen to january the fifteenth, two thousand and eighteen"
        check_interpret(sentence, interpretation: "date_interval", solution: solution )
        check_interpret("from 3/12/2017 to 15/01/2018", interpretation: "date_interval", solution: solution )
        check_interpret("du 3/12/2017 au 15/01/2018", interpretation: "date_interval", solution: solution )
      end

      def test_complex_date_in_period
        now = "2016-02-28T00:00:00+03:00"
        expected = {"date_range"=>
            {"start"=>"2016-03-02T00:00:00+03:00", "end"=>"2016-03-02T23:59:59+03:00"}
        }
        check_interpret("dans 3 jours", interpretation: "latency", solution: expected, now: now)
        check_interpret("dans trois jours", interpretation: "latency", solution: expected, now: now)
        check_interpret("in 3 days", interpretation: "latency", solution: expected, now: now)
        check_interpret("in three days", interpretation: "latency", solution: expected, now: now)

        expected = {"date_range"=>
            {"start"=>"2016-03-13T00:00:00+03:00", "end"=>"2016-03-19T23:59:59+03:00"}
        }
        check_interpret("dans 2 semaines", interpretation: "latency", solution: expected, now: now)

        expected = {"date_range"=>
            {"start"=>"2016-03-01T00:00:00+03:00", "end"=>"2016-03-31T23:59:59+03:00"}
        }
#        check_interpret("dans 1 mois", interpretation: "latency", solution: expected, now: now)

        expected = {"date_range"=>
            {"start"=>"2016-06-05T00:00:00+03:00", "end"=>"2016-06-5T23:59:59+03:00"}
        }
#        check_interpret("dans 3 mois 1 semaine et 1 jour", interpretation: "latency", solution: expected, now: now)
      end

      def test_complex_date_in_period_for_period
        now = "2016-02-28T00:00:00+03:00"

        date_begin = "2016-03-31T00:00:00+03:00"
        date_end = "2016-04-07T00:00:00+03:00"
        check_interpret("pour 1 semaine dans 1 mois et 3 jours", interpretation: "duration_with_latency", solution: {
          "date_begin" => date_begin,
          "date_end" => date_end
        }, now: now)
        check_interpret("pour une semaine dans un mois et trois jours", interpretation: "duration_with_latency", solution: {
          "date_begin" => date_begin,
          "date_end" => date_end
        }, now: now)
        check_interpret("for one week in one month and three days", interpretation: "duration_with_latency", solution: {
          "date_begin" => date_begin,
          "date_end" => date_end
        }, now: now)
        check_interpret("for 1 week in 1 month and 3 days", interpretation: "duration_with_latency", solution: {
          "date_begin" => date_begin,
          "date_end" => date_end
        }, now: now)
      end

      def test_complex_date_for_period
        now = "2016-02-28T00:00:00+03:00"

        date_range = "P7D"
        check_interpret("pour une semaine", interpretation: "period", solution: {"date_range" => date_range}, now: now)
        check_interpret("pour 1 semaine", interpretation: "period", solution: {"date_range" => date_range}, now: now)
        check_interpret("for one week", interpretation: "period", solution: {"date_range" => date_range}, now: now)
        check_interpret("for 1 week", interpretation: "period", solution: {"date_range" => date_range}, now: now)

        date_range = "P3M"
        check_interpret("for 3 months", interpretation: "period", solution: {"date_range" => date_range}, now: now)

        date_range = "P3M2D"
        check_interpret("for 3 months and 2 days", interpretation: "period", solution: {"date_range" => date_range}, now: now)

      end

      #      def test_extra
      #      end

    end
  end
end
