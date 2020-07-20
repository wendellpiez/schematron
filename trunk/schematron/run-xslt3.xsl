<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:nm="http://csrc.nist.gov/ns/metaschema"
    exclude-result-prefixes="xs nm"
    version="3.0">
    
    
    <!-- 
        
    Schematron application shell
      (flag -s) -s (--source) your XML document to be validated
      (parameter 'schematron') schematron=file.sch nominating the Schematron at location 'file.sch'
        relative to the input document
      
    To apply the Schematron, an executable transformation is dynamically produced
      from the input Schematron (source) by applying these transformations in sequence
    # code/iso_dsdl_include.xsl
    # code/iso_abstract_expand.xsl
    # code/iso_svrl_for_xslt2.xsl
   
   The resulting stylesheet is applied to the (nominal) main input of this XSLT.
   
   Results (outputs) should be SVRL.
   
    -->
    
    <xsl:variable name="xslt-base" select="document('')/document-uri()"/>
    
    <xsl:param name="document" select="/"/>
    
    <xsl:param name="schematron" as="xs:string"/>
    <xsl:param name="schematron-in">
        <xsl:try select="document($schematron,/)">
            <xsl:catch expand-text="true"> No Schematron found at { $schematron }</xsl:catch>
        </xsl:try>
    </xsl:param>
    
    <xsl:param name="louder" as="xs:string">quieter</xsl:param>
    
    <xsl:template match="/" name="apply-schematron">
        <xsl:param name="validate-me" as="document-node()" select="$document"/>
        <xsl:variable name="xslt-spec" select="'compiled-schematron.xsl'"/><!-- nominal location for generated XSLT -->
        <xsl:variable name="validation-params" as="map(xs:QName,item()*)?"/><!-- no params set outside globals (see below) -->
        <xsl:variable name="runtime" as="map(xs:string, item())">
            <xsl:map>
                <xsl:map-entry key="'xslt-version'"        select="3.0"/>
                <xsl:map-entry key="'stylesheet-node'">
                    <xsl:call-template name="produce-schematron"/>
                </xsl:map-entry>
                <xsl:map-entry key="'source-node'"         select="$validate-me"/>
            </xsl:map>
        </xsl:variable>
        <!-- The function returns a map; primary results are under 'output'
             unless a base output URI is given
             https://www.w3.org/TR/xpath-functions-31/#func-transform -->
        <xsl:sequence select="transform($runtime)?output"/>
        <xsl:call-template name="alert">
            <xsl:with-param name="msg" expand-text="true"> ... applied Schematron ... </xsl:with-param>
        </xsl:call-template>
        
    </xsl:template>
    
    <xsl:template name="produce-schematron" as="document-node()">
        <xsl:param name="source"   as="document-node()"  select="$schematron-in"/>
        <!-- Each element inside $schematron pipeline is processed in turn.
             The result of each processing step is passed to the next step as its input, until no steps are left. -->
        <xsl:variable name="schematron-pipeline">
            <nm:transform version="2.0">code/iso_dsdl_include.xsl</nm:transform>
            <nm:transform version="2.0">code/iso_abstract_expand.xsl</nm:transform>
            <nm:transform version="2.0">code/iso_svrl_for_xslt2.xsl</nm:transform>
        </xsl:variable>
        <xsl:iterate select="$schematron-pipeline/*">
            <xsl:param name="doc" select="$source" as="document-node()"/>
            <xsl:on-completion select="$doc"/>
            <xsl:next-iteration>
                <xsl:with-param name="doc">
                    <xsl:apply-templates mode="nm:execute" select=".">
                        <xsl:with-param name="sourcedoc" select="$doc"/>
                    </xsl:apply-templates>
                </xsl:with-param>
            </xsl:next-iteration>
        </xsl:iterate>
    </xsl:template>
    
    <xsl:template mode="nm:execute" match="nm:transform">
        <xsl:param name="sourcedoc" as="document-node()"/>
        <xsl:variable name="xslt-spec" select="."/>
        <xsl:variable name="runtime-params" as="map(xs:QName,item()*)">
            <xsl:apply-templates select="." mode="nm:runtime-parameters"/>
        </xsl:variable>
        <xsl:variable name="runtime" as="map(xs:string, item())">
            <xsl:map>
                <xsl:map-entry key="'xslt-version'"        select="xs:decimal($xslt-spec/@version)"/>
                <xsl:map-entry key="'stylesheet-location'" select=" resolve-uri(string($xslt-spec),$xslt-base)"/>
                <xsl:map-entry key="'source-node'"         select="$sourcedoc"/>
                <xsl:map-entry key="'stylesheet-params'"   select="$runtime-params"/>
            </xsl:map>
        </xsl:variable>
        <!-- The function returns a map; primary results are under 'output'
             unless a base output URI is given
             https://www.w3.org/TR/xpath-functions-31/#func-transform -->
        <xsl:sequence select="transform($runtime)?output"/>
        <xsl:call-template name="alert">
            <xsl:with-param name="msg" expand-text="true"> ... applied step { count(.|preceding-sibling::*) }: XSLT { $xslt-spec } ... </xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    
    <!-- Not knowing any better, any other execution step passes through its source. -->
    <xsl:template mode="nm:execute" match="*">
        <xsl:param name="sourcedoc" as="document-node()"/>
        <xsl:call-template name="alert">
            <xsl:with-param name="msg" expand-text="true"> ... applied step { count(.|preceding-sibling::*) }: { name() } ...</xsl:with-param>
        </xsl:call-template>
        <xsl:sequence select="$sourcedoc"/>
    </xsl:template>
    
    <xsl:template name="alert">
        <xsl:param name="msg"/>
        <xsl:if test="not($louder=('quieter','no','false'))">
            <xsl:message>
                <xsl:sequence select="$msg"/>
            </xsl:message>
        </xsl:if>
    </xsl:template>
    
    <!-- In mode 'nm:runtime-parameters' we map parameters into the respective transformations...   -->
    
    <xsl:template mode="nm:runtime-parameters" match="*" as="map(xs:QName,item()*)">
        <xsl:map/>
    </xsl:template>
        
    <xsl:template mode="nm:runtime-parameters" match="nm:transform[.='code/iso_dsdl_include.xsl']" as="map(xs:QName,item()*)">
        <xsl:map>
            <xsl:map-entry key="QName('', 'include-schematron')" select="$include-schematron"/>
            <xsl:map-entry key="QName('', 'include-crdl')"       select="$include-crdl"/>
            <xsl:map-entry key="QName('', 'include-xinclude')"   select="$include-xinclude"/>
            <xsl:map-entry key="QName('', 'include-dtll')"       select="$include-dtll"/>
            <xsl:map-entry key="QName('', 'include-relaxng')"    select="$include-relaxng"/>
            <xsl:map-entry key="QName('', 'include-xlink')"      select="$include-xlink"/>
        </xsl:map>
    </xsl:template>
    
    <xsl:template mode="nm:runtime-parameters"
        match="nm:transform[. = 'code/iso_svrl_for_xslt2.xsl']" as="map(xs:QName,item()*)">
        <xsl:map>
            <xsl:map-entry key="QName('', 'diagnose')" select="$diagnose"/>
            <xsl:map-entry key="QName('', 'property')" select="$property"/>
            <xsl:map-entry key="QName('', 'phase')" select="$phase"/>
            <xsl:map-entry key="QName('', 'allow-foreign')" select="$allow-foreign"/>
            <xsl:map-entry key="QName('', 'generate-paths')" select="$generate-paths"/>
            <xsl:map-entry key="QName('', 'generate-fired-rule')" select="$generate-fired-rule"/>
            <xsl:map-entry key="QName('', 'optimize')" select="$optimize"/>
            <xsl:map-entry key="QName('', 'sch.exslt.imports')" select="$sch.exslt.imports"/>
            <xsl:map-entry key="QName('', 'terminate')" select="$terminate"/>
            <xsl:map-entry key="QName('', 'langCode')" select="$langCode"/>
            <xsl:map-entry key="QName('', 'output-encoding')" select="$output-encoding"/>
            <xsl:map-entry key="QName('', 'full-path-notation')" select="$full-path-notation"/>
            <xsl:map-entry key="QName('', 'include-schematron')" select="$include-schematron"/>
        </xsl:map>
    </xsl:template>
    
    
    <!--iso_dsdl_include.xsl-->
    
    <xsl:param name="include-schematron">true</xsl:param>
    <xsl:param name="include-crdl">true</xsl:param>
    <xsl:param name="include-xinclude">true</xsl:param>
    <xsl:param name="include-dtll">true</xsl:param>
    <xsl:param name="include-relaxng">true</xsl:param>
    <xsl:param name="include-xlink">true</xsl:param>
    
    <!--iso_abstract_expand.xsl-->
    
    <!-- code/iso_svrl_for_xslt2.xsl -->
    <xsl:param name="diagnose">true</xsl:param>
    <xsl:param name="property">true</xsl:param>
    <xsl:param name="phase"
        xmlns:schold="http://www.ascc.net/xml/schematron" 
        xmlns:iso="http://purl.oclc.org/dsdl/schematron" >
        <xsl:choose>
            <!-- Handle Schematron 1.5 and 1.6 phases -->
            <xsl:when test="//schold:schema/@defaultPhase">
                <xsl:value-of select="//schold:schema/@defaultPhase"/>
            </xsl:when>
            <!-- Handle ISO Schematron phases -->
            <xsl:when test="//iso:schema/@defaultPhase">
                <xsl:value-of select="//iso:schema/@defaultPhase"/>
            </xsl:when>
            <xsl:otherwise>#ALL</xsl:otherwise>
        </xsl:choose>
    </xsl:param>
    <xsl:param name="allow-foreign">true</xsl:param>
    <xsl:param name="generate-paths">true</xsl:param>
    <xsl:param name="generate-fired-rule">true</xsl:param>
    <xsl:param name="optimize" />
    <!-- e.g. saxon file.xml file.xsl "sch.exslt.imports=.../string.xsl;.../math.xsl" -->
    <xsl:param name="sch.exslt.imports" />
    
    <xsl:param name="terminate" >false</xsl:param>
    
    <!-- Set the language code for messages -->
    <xsl:param name="langCode">default</xsl:param>
    
    <xsl:param name="output-encoding"/>
    
    <!-- Set the default for schematron-select-full-path, i.e. the notation for svrl's @location-->
    <xsl:param name="full-path-notation">1</xsl:param>
    
</xsl:stylesheet>