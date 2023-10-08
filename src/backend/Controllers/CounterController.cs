using Dapr.Client;
using Microsoft.AspNetCore.Mvc;

namespace ContainerAppDemo.Backend.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class CounterController : ControllerBase
    {
        [HttpGet]
        public async Task<IActionResult> Get()
        {
            const string storeName = "statestore";
            const string key = "counter";

            var daprClient = new DaprClientBuilder().Build();
            var counter = await daprClient.GetStateAsync<int>(storeName, key);
            counter++;
            await daprClient.SaveStateAsync(storeName, key, counter);
            return Ok(counter);
        }
    }
}