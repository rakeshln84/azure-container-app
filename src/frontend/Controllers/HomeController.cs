using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;
using ContainerAppDemo.Frontend.Models;
using Newtonsoft.Json;

namespace ContainerAppDemo.Frontend.Controllers
{
    public class HomeController : Controller
    {
        const string storeName = "statestore";
        const string key = "counter";

        private readonly ILogger<HomeController> _logger;

        public HomeController(ILogger<HomeController> logger)
        {
            _logger = logger;
        }

        public async Task<IActionResult> Index()
        {
            var port = Environment.GetEnvironmentVariable("DAPR_HTTP_PORT");
            HttpClient client = new HttpClient();
            var re = await client.GetAsync($"http://localhost:{port}/v1.0/invoke/backendapp/method/counter");
            var text = await re.Content.ReadAsStringAsync();
            ViewBag.Text = text + "," + re.StatusCode + ",";
            ViewBag.Counter = JsonConvert.DeserializeObject<string>(text);
            return View();
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}