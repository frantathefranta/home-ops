
# Table of Contents

1.  [Introduction](#org56a5c31)
2.  [Cloud dependency](#org689b93f)
3.  [Gatus](#gatus)

<a id="org56a5c31"></a>

# Introduction

This is my repo detailing home-ops based around Kubernetes (ran on Talos Linux).
It&rsquo;s based on the [cluster-template](https://github.com/onedr0p/cluster-template) generously created and maintained by [onedr0p](https://github.com/onedr0p). Slight modifications were made by me (because I don&rsquo;t know better).


<a id="org689b93f"></a>

# Cloud dependency

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">Service</th>
<th scope="col" class="org-left">Use</th>
<th scope="col" class="org-left">Cost</th>
</tr>
</thead>
<tbody>
<tr>
<td class="org-left">Akeyless</td>
<td class="org-left">External Secrets store</td>
<td class="org-left">$0/yr (for now)</td>
</tr>

<tr>
<td class="org-left">Google Cloud</td>
<td class="org-left">Hosting uptime-kuma</td>
<td class="org-left">$0/yr (free tier)</td>
</tr>

<tr>
<td class="org-left">Cloudflare</td>
<td class="org-left">Domain, Zero Trust tunnel, R2 storage</td>
<td class="org-left">~$7/yr</td>
</tr>

<tr>
<td class="org-left">GitHub</td>
<td class="org-left">Repo hosting, runners</td>
<td class="org-left">$0/yr</td>
</tr>

<tr>
<td class="org-left">Purelymail</td>
<td class="org-left">Email hosting for my domain</td>
<td class="org-left">$10/yr</td>
</tr>

<tr>
<td class="org-left">Pushover</td>
<td class="org-left">Notifications</td>
<td class="org-left">$5</td>
</tr>
</tbody>
</table>

<a id="gatus"></a>

# Gatus

[Status dashboard](https://status.franta.us) ·
[Configuration](kubernetes/apps/observability/gatus)
