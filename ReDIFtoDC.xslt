<xsl:stylesheet version="1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/">
    <xsl:variable name="JELLookup" select="document('JELCodeLookup.xml')"/>
    <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" omit-xml-declaration="yes"/>
    <xsl:template match="/opt">
            <!--record xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:dcterms="http://purl.org/dc/terms/"-->
            <record>                
                <xsl:call-template name="copyField">
                    <xsl:with-param name="paraNode"><xsl:text>dc:title</xsl:text></xsl:with-param>
                    <xsl:with-param name="paraValue"><xsl:value-of select="title"/></xsl:with-param> 
                </xsl:call-template>
                <xsl:apply-templates select="author"/>      
                <xsl:element name="dc:type">preprint</xsl:element>
                <xsl:call-template name="copyField">
                    <xsl:with-param name="paraNode"><xsl:text>dcterms:abstract</xsl:text></xsl:with-param>
                    <xsl:with-param name="paraValue"><xsl:value-of select="abstract"/></xsl:with-param> 
                </xsl:call-template>
                <xsl:if test="keywords">
                    <xsl:call-template name="processKeywords">
                        <xsl:with-param name="paraKeywords">
                            <xsl:value-of select="keywords"/>
                        </xsl:with-param>
                    </xsl:call-template>
                </xsl:if>
                <xsl:element name="dcterms:IsPartof">
                    <xsl:choose>
                        <xsl:when test="series">
                            <xsl:value-of select="concat(series,' Number ',number)"/>    
                        </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('Number ',number)"/>
                    </xsl:otherwise>
                    </xsl:choose>
                </xsl:element>
                <xsl:call-template name="copyField">
                    <xsl:with-param name="paraNode"><xsl:text>dc:date</xsl:text></xsl:with-param>
                    <xsl:with-param name="paraValue"><xsl:value-of select="substring-before(creation-date,'-')"/></xsl:with-param> 
                </xsl:call-template> 
                <xsl:if test="classification-jel">
                    <xsl:call-template name="processCodes">
                        <xsl:with-param name="paramCodes" select="classification-jel"/>
                    </xsl:call-template>
                </xsl:if>
                <xsl:choose>
                    <xsl:when test="file/url">
                        <xsl:call-template name="copyField">
                            <xsl:with-param name="paraNode"><xsl:text>dcterms:URI</xsl:text></xsl:with-param>
                            <xsl:with-param name="paraValue"><xsl:value-of select="file/url"/></xsl:with-param> 
                        </xsl:call-template> 
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:element name="dcterms:IsVersionOf">
                            <xsl:attribute name="type">URI</xsl:attribute>
                            <xsl:value-of select="concat('http://ideas.repec.org/p/boc/bocoec/',substring(handle,18,3),'.html')"/>
                        </xsl:element>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:call-template name="copyField">
                    <xsl:with-param name="paraNode"><xsl:text>dc:identifier</xsl:text></xsl:with-param>
                    <xsl:with-param name="paraValue"><xsl:value-of select="handle"/></xsl:with-param> 
                </xsl:call-template>                
                <xsl:element name="dcterms:isReferencedBy">Working Papers in Economics</xsl:element>
            </record>
    </xsl:template>
    <xsl:template name="copyField">
        <xsl:param name="paraNode"/>
        <xsl:param name="paraValue"/>
        <xsl:if test="$paraValue !=''">
            <xsl:element name="{$paraNode}">
                <xsl:value-of select="$paraValue"/>
            </xsl:element>
        </xsl:if>
    </xsl:template>        
    <xsl:template match="author">
        <xsl:choose>
            <xsl:when test="x-name-last">
                <xsl:element name="dc:creator">
                    <xsl:value-of select="concat(x-name-last, ', ', x-name-first)"/>
                </xsl:element>
                <xsl:if test="workplace/name">
                    <xsl:element name="dc:description">
                        <xsl:value-of select="concat(x-name-last, ', ', x-name-first, '. ', workplace/name)"/>
                    </xsl:element>  
                </xsl:if>
            </xsl:when>
            <xsl:otherwise>
                <xsl:element name="dc:creator">
                    <xsl:value-of select="name"/>
                </xsl:element>
                <xsl:if test="workplace/name">
                    <xsl:element name="dc:description">
                        <xsl:value-of select="concat(name, '. ', workplace/name)"/>
                    </xsl:element>  
                </xsl:if>                
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="processKeywords">
        <xsl:param name="paraKeywords"/>
        <xsl:choose>
            <xsl:when test="contains($paraKeywords, ',')">
                <xsl:element name="dcterms:keyword">
                    <xsl:value-of select="substring-before($paraKeywords, ',')"/>
                </xsl:element> 
                <xsl:call-template name="processKeywords">
                    <xsl:with-param name="paraKeywords">
                        <xsl:value-of select="normalize-space(substring-after($paraKeywords,','))"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:element name="dcterms:keyword">
                    <xsl:value-of select="$paraKeywords"/>
                </xsl:element>                 
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>  
    <xsl:template name="processCodes">
        <xsl:param name="paramCodes"/>
        <xsl:choose>
            <xsl:when test="contains($paramCodes, ' ')">
                <xsl:variable name="vCode" select="substring-before($paramCodes, ' ')"/>
                <dc:subject>
                    <xsl:value-of select="$JELLookup/JELLookUp/JELCodeToValue[@code=$vCode]/@value"/>
                </dc:subject>
                <xsl:call-template name="processCodes">
                    <xsl:with-param name="paramCodes" select="normalize-space(substring-after($paramCodes, ' '))"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="vCode" select="$paramCodes"/>
                <dc:subject>
                    <xsl:value-of select="$JELLookup/JELLookUp/JELCodeToValue[@code=$vCode]/@value"/>
                </dc:subject>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>    
    <xsl:template match="text()"/>
</xsl:stylesheet>
