using System;
using System.Globalization;
using Amazon.Lambda.Core;
using Calculator.InputModel;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]
namespace Calculator;

public class Function
{
    public int FunctionHandler(FunctionInput input, ILambdaContext context)
    {
        int days = 0;

        DateTime fromDate;
        DateTime toDate;

        // check format
        if(!DateTime.TryParseExact(input.FromDate, "MM/dd/yyyy",CultureInfo.InvariantCulture, DateTimeStyles.None, out fromDate) ||
           !DateTime.TryParseExact(input.ToDate, "MM/dd/yyyy", CultureInfo.InvariantCulture, DateTimeStyles.None, out toDate))
        {
            return 0;
        }

        // check boundary
        if (fromDate > DateTime.MaxValue.AddDays(-2) ||
            toDate < DateTime.MinValue.AddDays(2))
        {
            return 0;
        }

        // check valid FromDate and ToDate
        toDate = toDate.AddDays(-1);

        if (toDate <= fromDate)
        {
            return 0;
        }

        while (fromDate < toDate)
        {
            fromDate = fromDate.AddDays(1);

            if (fromDate.DayOfWeek != DayOfWeek.Saturday && fromDate.DayOfWeek != DayOfWeek.Sunday)
            {
                days++;
            }
        }

        return days;
    }
}