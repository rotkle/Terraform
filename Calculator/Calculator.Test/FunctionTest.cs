using Amazon.Lambda.Core;
using Calculator.InputModel;
using Moq;

namespace Calculator.Test;

public class FunctionTest
{
    [Theory]
    [InlineData(null, null)]
    [InlineData(null, "01/20/2022")]
    [InlineData("01/20/2022", null)]
    [InlineData("20/01/2022","30/01/2022")]
    [InlineData("20/01/2022", "01/30/2022")]
    [InlineData("01/20/2022", "30/01/2022")]
    public void ShouldReturn0_WhenGivenInvalidFormatValues_NotMMDDYYYY(string fromDate, string toDate)
    {
        // Arrange
        FunctionInput input = new FunctionInput();
        input.FromDate = fromDate;
        input.ToDate = toDate;

        Function f = new Function();

        // Act
        int actResult = f.FunctionHandler(input, new Mock<ILambdaContext>().Object);

        // Assert
        Assert.Equal(0, actResult);
    }

    [Theory]
    [InlineData("12/30/9999", "12/30/9999")] // boundary at fromDate
    [InlineData("01/01/0001", "01/02/0001")] // boundary at toDate
    public void ShouldReturn0_WhenGivenBoundaryValues(string fromDate, string toDate)
    {
        // Arrange
        FunctionInput input = new FunctionInput();
        input.FromDate = fromDate;
        input.ToDate = toDate;

        Function f = new Function();

        // Act
        int actResult = f.FunctionHandler(input, new Mock<ILambdaContext>().Object);

        // Assert
        Assert.Equal(0, actResult);
    }

    [Theory]
    [InlineData("01/20/2022","01/19/2022")]
    [InlineData("01/20/2022","01/20/2022")]
    [InlineData("01/20/2022", "01/21/2022")]
    public void ShouldReturn0_WhenGivenInvalidValues_ToDateNotMakeSenseWithFromDate(string fromDate, string toDate)
    {
        // Arrange
        FunctionInput input = new FunctionInput();
        input.FromDate = fromDate;
        input.ToDate = toDate;

        Function f = new Function();

        // Act
        int actResult = f.FunctionHandler(input, new Mock<ILambdaContext>().Object);

        // Assert
        Assert.Equal(0, actResult);
    }

    [Theory]
    [InlineData("08/04/2021","08/06/2021",1)]
    [InlineData("08/02/2021","08/12/2021",7)]
    [InlineData("01/20/2022","01/22/2022",1)]
    [InlineData("02/10/2022","03/04/2022",15)]
    public void ShouldReturnRightDays_WhenGivenValidValues(string fromDate, string toDate, int expectedDays)
    {
        // Arrange
        FunctionInput input = new FunctionInput();
        input.FromDate = fromDate;
        input.ToDate = toDate;

        Function f = new Function();

        // Act
        int actResult = f.FunctionHandler(input, new Mock<ILambdaContext>().Object);

        // Assert
        Assert.Equal(expectedDays, actResult);
    }
}
